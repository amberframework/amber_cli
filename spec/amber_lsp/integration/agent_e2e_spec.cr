require "../spec_helper"

# End-to-end test that simulates an AI agent using the amber-lsp.
#
# The test proves the full feedback cycle:
#   1. Agent opens a file with Amber convention violations
#   2. LSP returns diagnostics identifying specific violations
#   3. Agent reads diagnostics, determines the fix
#   4. Agent saves the corrected file
#   5. LSP returns clean diagnostics (no violations)
#
# This demonstrates that an agent receiving LSP diagnostics can act on them
# to produce correct Amber code — the information loop works end-to-end.

private def lsp_frame(message) : String
  json = message.to_json
  "Content-Length: #{json.bytesize}\r\n\r\n#{json}"
end

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

private def collect_responses(io : IO) : Array(JSON::Any)
  responses = [] of JSON::Any
  loop do
    response = read_lsp_response(io)
    break if response.nil?
    responses << response
  end
  responses
end

AGENT_E2E_BINARY_PATH = File.join(Dir.current, "bin", "amber-lsp")

describe "Agent E2E: LSP diagnostic feedback loop" do
  it "agent opens bad file, receives diagnostics, fixes file, receives clean diagnostics" do
    with_tempdir do |dir|
      # --- Setup: create a minimal Amber project ---
      shard_content = <<-YAML
      name: agent_test_project
      version: 0.1.0
      dependencies:
        amber:
          github: amberframework/amber
      YAML
      File.write(File.join(dir, "shard.yml"), shard_content)
      Dir.mkdir_p(File.join(dir, "src", "controllers"))
      Dir.mkdir_p(File.join(dir, "spec", "controllers"))

      root_uri = "file://#{dir}"
      file_uri = "file://#{dir}/src/controllers/users_controller.cr"

      # Create corresponding spec file (so spec-existence rule is satisfied)
      File.write(File.join(dir, "spec", "controllers", "users_controller_spec.cr"), "# spec placeholder")

      # --- Step 1: Agent opens a file with multiple violations ---
      # Violations:
      #   - Class name "UsersHandler" doesn't end with "Controller" (amber/controller-naming)
      #   - Public action "index" doesn't call render/redirect_to (amber/action-return-type)
      bad_code = <<-CRYSTAL
      class UsersHandler < Amber::Controller::Base
        def index
          users = ["Alice", "Bob"]
        end
      end
      CRYSTAL

      # --- Step 2: Agent sends the file to the LSP ---
      # Build the initial LSP session: initialize + didOpen
      init_messages = [
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
              "text"       => bad_code,
            },
          },
        }),
      ]

      # --- Step 3: Agent reads diagnostics and determines the fix ---
      # The corrected code:
      #   - Renamed "UsersHandler" → "UsersController" (fixes controller-naming)
      #   - Added render call in index (fixes action-return-type)
      fixed_code = <<-CRYSTAL
      class UsersController < Amber::Controller::Base
        def index
          users = ["Alice", "Bob"]
          render("index.ecr")
        end
      end
      CRYSTAL

      # --- Step 4: Agent saves the corrected file ---
      save_and_shutdown = [
        lsp_frame({
          "jsonrpc" => "2.0",
          "method"  => "textDocument/didSave",
          "params"  => {
            "textDocument" => {"uri" => file_uri},
            "text"         => fixed_code,
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

      # Combine all messages into one session
      all_messages = init_messages.map(&.as(String)).join + save_and_shutdown.map(&.as(String)).join

      # Spawn the LSP binary
      process = Process.new(
        AGENT_E2E_BINARY_PATH,
        input: Process::Redirect::Pipe,
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Close
      )

      process.input.print(all_messages)
      process.input.close

      responses = collect_responses(process.output)
      process.output.close

      status = process.wait
      status.success?.should be_true

      # --- Verify Step 2: Initial diagnostics have violations ---
      diag_notifications = responses.select { |r|
        r["method"]?.try(&.as_s?) == "textDocument/publishDiagnostics"
      }

      # We should get exactly 2 publishDiagnostics notifications:
      # 1st from didOpen (with violations), 2nd from didSave (clean)
      diag_notifications.size.should eq(2)

      # First notification: violations detected
      first_diag = diag_notifications[0]
      first_diag["params"]["uri"].as_s.should eq(file_uri)
      violations = first_diag["params"]["diagnostics"].as_a
      violation_codes = violations.map { |d| d["code"].as_s }

      # Agent received these specific violations from the LSP
      violation_codes.should contain("amber/controller-naming")
      violation_codes.should contain("amber/action-return-type")

      # Verify diagnostics have actionable messages
      naming_diag = violations.find { |d| d["code"].as_s == "amber/controller-naming" }.not_nil!
      naming_diag["message"].as_s.should contain("Controller")
      naming_diag["source"].as_s.should eq("amber-lsp")
      naming_diag["severity"].as_i.should eq(1) # Error severity

      action_diag = violations.find { |d| d["code"].as_s == "amber/action-return-type" }.not_nil!
      action_diag["source"].as_s.should eq("amber-lsp")

      # --- Verify Step 4: After fix, diagnostics are clean ---
      second_diag = diag_notifications[1]
      second_diag["params"]["uri"].as_s.should eq(file_uri)
      clean_diagnostics = second_diag["params"]["diagnostics"].as_a

      # No violations after the agent's fix
      clean_diagnostics.should be_empty

      # --- Verify: LSP session completed cleanly ---
      shutdown_response = responses.find { |r| r["id"]?.try(&.as_i?) == 2 }
      shutdown_response.should_not be_nil
    end
  end
end
