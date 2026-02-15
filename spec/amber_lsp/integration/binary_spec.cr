require "../spec_helper"

# Helper to format a JSON message as an LSP-framed message (Content-Length header + body)
private def lsp_frame(message) : String
  json = message.to_json
  "Content-Length: #{json.bytesize}\r\n\r\n#{json}"
end

# Helper to read a single LSP response from an IO.
# Returns the parsed JSON, or nil if no more data is available.
private def read_lsp_response(io : IO) : JSON::Any?
  content_length = -1

  loop do
    line = io.gets
    return nil if line.nil?

    line = line.chomp
    break if line.empty?

    if line.starts_with?("Content-Length:")
      content_length = line.split(":")[1].strip.to_i
    end
  end

  return nil if content_length < 0

  body = Bytes.new(content_length)
  io.read_fully(body)
  JSON.parse(String.new(body))
rescue IO::EOFError
  nil
end

# Helper to collect all LSP responses from a process output until EOF.
private def collect_responses(io : IO) : Array(JSON::Any)
  responses = [] of JSON::Any
  loop do
    response = read_lsp_response(io)
    break if response.nil?
    responses << response
  end
  responses
end

BINARY_PATH = File.join(Dir.current, "bin", "amber-lsp")

describe "amber-lsp binary" do
  it "binary exists and is executable" do
    File.exists?(BINARY_PATH).should be_true
    File.info(BINARY_PATH).permissions.owner_execute?.should be_true
  end

  it "responds to initialize and produces diagnostics via stdio" do
    with_tempdir do |dir|
      # Create an Amber project
      shard_content = <<-YAML
      name: test_project
      version: 0.1.0
      dependencies:
        amber:
          github: amberframework/amber
      YAML
      File.write(File.join(dir, "shard.yml"), shard_content)
      Dir.mkdir_p(File.join(dir, "src", "controllers"))

      root_uri = "file://#{dir}"
      file_uri = "file://#{dir}/src/controllers/bad_handler.cr"

      bad_controller = <<-CRYSTAL
      class BadHandler < ApplicationController
        def index
          # TODO: implement
        end
      end
      CRYSTAL

      # Build the sequence of LSP messages
      messages = [
        lsp_frame({
          "jsonrpc" => "2.0",
          "id"      => 1,
          "method"  => "initialize",
          "params"  => {
            "rootUri"      => root_uri,
            "capabilities" => {} of String => String,
          },
        }),
        lsp_frame({
          "jsonrpc" => "2.0",
          "method"  => "initialized",
          "params"  => {} of String => String,
        }),
        lsp_frame({
          "jsonrpc" => "2.0",
          "method"  => "textDocument/didOpen",
          "params"  => {
            "textDocument" => {
              "uri"        => file_uri,
              "languageId" => "crystal",
              "version"    => 1,
              "text"       => bad_controller,
            },
          },
        }),
        lsp_frame({
          "jsonrpc" => "2.0",
          "id"      => 2,
          "method"  => "shutdown",
        }),
        lsp_frame({
          "jsonrpc" => "2.0",
          "method"  => "exit",
        }),
      ]

      input_data = messages.join

      # Spawn the binary process
      process = Process.new(
        BINARY_PATH,
        input: Process::Redirect::Pipe,
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Close
      )

      # Write all LSP messages to the process stdin
      process.input.print(input_data)
      process.input.close

      # Read all responses from stdout
      responses = collect_responses(process.output)
      process.output.close

      # Wait for the process to finish
      status = process.wait
      status.success?.should be_true

      # Verify we got responses
      responses.size.should be >= 3

      # First response: initialize result
      init_response = responses[0]
      init_response["id"].as_i.should eq(1)
      init_response["result"]["serverInfo"]["name"].as_s.should eq("amber-lsp")
      init_response["result"]["serverInfo"]["version"].as_s.should eq(AmberLSP::VERSION)

      # Second response: publishDiagnostics notification
      diag_notification = responses[1]
      diag_notification["method"].as_s.should eq("textDocument/publishDiagnostics")
      diag_notification["params"]["uri"].as_s.should eq(file_uri)

      diagnostics = diag_notification["params"]["diagnostics"].as_a
      codes = diagnostics.map { |d| d["code"].as_s }

      # BadHandler triggers controller-naming; missing response method triggers action-return-type
      codes.should contain("amber/controller-naming")
      codes.should contain("amber/action-return-type")

      # Verify proper LSP diagnostic structure
      diagnostics.each do |diag|
        diag["source"].as_s.should eq("amber-lsp")
        diag["range"]["start"]["line"].as_i.should be >= 0
        diag["range"]["start"]["character"].as_i.should be >= 0
        diag["severity"].as_i.should be >= 1
        diag["severity"].as_i.should be <= 4
      end

      # Last response: shutdown with null result
      shutdown_response = responses.find { |r| r["id"]?.try(&.as_i?) == 2 }
      shutdown_response.should_not be_nil
      shutdown_response.not_nil!["result"].raw.should be_nil
    end
  end

  it "produces no diagnostics for non-Amber projects via stdio" do
    with_tempdir do |dir|
      # Create a non-Amber project
      shard_content = <<-YAML
      name: plain_project
      version: 0.1.0
      dependencies:
        kemal:
          github: kemalcr/kemal
      YAML
      File.write(File.join(dir, "shard.yml"), shard_content)
      Dir.mkdir_p(File.join(dir, "src", "controllers"))

      root_uri = "file://#{dir}"
      file_uri = "file://#{dir}/src/controllers/bad_handler.cr"

      bad_controller = <<-CRYSTAL
      class BadHandler < HTTP::Server
        def index
        end
      end
      CRYSTAL

      messages = [
        lsp_frame({
          "jsonrpc" => "2.0",
          "id"      => 1,
          "method"  => "initialize",
          "params"  => {
            "rootUri"      => root_uri,
            "capabilities" => {} of String => String,
          },
        }),
        lsp_frame({
          "jsonrpc" => "2.0",
          "method"  => "initialized",
          "params"  => {} of String => String,
        }),
        lsp_frame({
          "jsonrpc" => "2.0",
          "method"  => "textDocument/didSave",
          "params"  => {
            "textDocument" => {"uri" => file_uri},
            "text"         => bad_controller,
          },
        }),
        lsp_frame({
          "jsonrpc" => "2.0",
          "id"      => 2,
          "method"  => "shutdown",
        }),
        lsp_frame({
          "jsonrpc" => "2.0",
          "method"  => "exit",
        }),
      ]

      input_data = messages.join

      process = Process.new(
        BINARY_PATH,
        input: Process::Redirect::Pipe,
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Close
      )

      process.input.print(input_data)
      process.input.close

      responses = collect_responses(process.output)
      process.output.close

      status = process.wait
      status.success?.should be_true

      # Should have initialize and shutdown responses only (no publishDiagnostics)
      diag_notifications = responses.select { |r| r["method"]?.try(&.as_s?) == "textDocument/publishDiagnostics" }
      diag_notifications.should be_empty
    end
  end

  it "handles job rule violations via stdio" do
    with_tempdir do |dir|
      shard_content = <<-YAML
      name: test_project
      version: 0.1.0
      dependencies:
        amber:
          github: amberframework/amber
      YAML
      File.write(File.join(dir, "shard.yml"), shard_content)
      Dir.mkdir_p(File.join(dir, "src", "jobs"))

      root_uri = "file://#{dir}"
      file_uri = "file://#{dir}/src/jobs/bad_job.cr"

      bad_job = <<-CRYSTAL
      class BadJob < Amber::Jobs::Job
      end
      CRYSTAL

      messages = [
        lsp_frame({
          "jsonrpc" => "2.0",
          "id"      => 1,
          "method"  => "initialize",
          "params"  => {
            "rootUri"      => root_uri,
            "capabilities" => {} of String => String,
          },
        }),
        lsp_frame({
          "jsonrpc" => "2.0",
          "method"  => "initialized",
          "params"  => {} of String => String,
        }),
        lsp_frame({
          "jsonrpc" => "2.0",
          "method"  => "textDocument/didOpen",
          "params"  => {
            "textDocument" => {
              "uri"        => file_uri,
              "languageId" => "crystal",
              "version"    => 1,
              "text"       => bad_job,
            },
          },
        }),
        lsp_frame({
          "jsonrpc" => "2.0",
          "id"      => 2,
          "method"  => "shutdown",
        }),
        lsp_frame({
          "jsonrpc" => "2.0",
          "method"  => "exit",
        }),
      ]

      input_data = messages.join

      process = Process.new(
        BINARY_PATH,
        input: Process::Redirect::Pipe,
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Close
      )

      process.input.print(input_data)
      process.input.close

      responses = collect_responses(process.output)
      process.output.close

      status = process.wait
      status.success?.should be_true

      diag_notifications = responses.select { |r| r["method"]?.try(&.as_s?) == "textDocument/publishDiagnostics" }
      diag_notifications.size.should be >= 1

      codes = diag_notifications[0]["params"]["diagnostics"].as_a.map { |d| d["code"].as_s }
      codes.should contain("amber/job-perform")
      codes.should contain("amber/job-serializable")
    end
  end

  it "exits cleanly after shutdown + exit sequence" do
    with_tempdir do |dir|
      shard_content = <<-YAML
      name: test_project
      version: 0.1.0
      dependencies:
        amber:
          github: amberframework/amber
      YAML
      File.write(File.join(dir, "shard.yml"), shard_content)

      root_uri = "file://#{dir}"

      messages = [
        lsp_frame({
          "jsonrpc" => "2.0",
          "id"      => 1,
          "method"  => "initialize",
          "params"  => {
            "rootUri"      => root_uri,
            "capabilities" => {} of String => String,
          },
        }),
        lsp_frame({
          "jsonrpc" => "2.0",
          "method"  => "initialized",
          "params"  => {} of String => String,
        }),
        lsp_frame({
          "jsonrpc" => "2.0",
          "id"      => 2,
          "method"  => "shutdown",
        }),
        lsp_frame({
          "jsonrpc" => "2.0",
          "method"  => "exit",
        }),
      ]

      input_data = messages.join

      process = Process.new(
        BINARY_PATH,
        input: Process::Redirect::Pipe,
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Close
      )

      process.input.print(input_data)
      process.input.close

      responses = collect_responses(process.output)
      process.output.close

      status = process.wait
      status.success?.should be_true

      # Should have initialize response and shutdown response
      responses.size.should eq(2)

      init_response = responses[0]
      init_response["id"].as_i.should eq(1)
      init_response["result"]["serverInfo"]["name"].as_s.should eq("amber-lsp")

      shutdown_response = responses[1]
      shutdown_response["id"].as_i.should eq(2)
      shutdown_response["result"].raw.should be_nil
    end
  end
end
