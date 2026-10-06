#!/usr/bin/env ruby
# frozen_string_literal: true

# lsp_smoke.rb — live-fire proof that the built `amber-lsp` binary really
# speaks LSP over stdio, publishes diagnostics, and serves API lookups.
#
# The Crystal specs under spec/amber_lsp/ exercise the server class in-process
# with an IO::Memory pair. That proves the code, not the binary: it cannot
# catch a stale binary on disk, a broken build, or a server that hangs instead
# of answering. This script spawns the ACTUAL executable, drives a real framed
# stdio session against a throwaway Amber-shaped project, and checks diagnostics
# plus workspace/symbol, hover, and definition responses.
#
#   scripts/lsp_smoke.rb                       # uses ./bin/amber-lsp
#   scripts/lsp_smoke.rb --server /path/to/amber-lsp
#   scripts/lsp_smoke.rb --timeout 20 --keep   # keep the fixture project
#
# Exit 0 = the diagnostic fixtures pass and the binary resolves the fixture
# symbol through workspace/symbol, hover, and definition.
# Exit 1 = live-fire expectations not met. Exit 2 = could not run at all (no
# binary, handshake failure, timeout). A timeout is never reported as a pass —
# "I could not measure it" is not "it is clean".
#
# Ruby 2.6 compatible on purpose: it must run under macOS system ruby with no
# gems, so it works anywhere the binary does.

require "json"
require "fileutils"
require "tmpdir"

module LSPSmoke
  EXIT_OK      = 0
  EXIT_FAILED  = 1
  EXIT_CANNOT  = 2

  # LSP DiagnosticSeverity
  SEVERITY = { 1 => "error", 2 => "warning", 3 => "info", 4 => "hint" }.freeze

  # Reads `Content-Length: N\r\n\r\n<json>` frames off a pipe under a deadline.
  # Buffered + non-blocking so a server that goes quiet times out instead of
  # wedging the script forever.
  class FrameReader
    def initialize(io)
      @io = io
      @buf = String.new.force_encoding(Encoding::BINARY)
    end

    def read_frame(deadline)
      loop do
        frame = take_frame
        return frame if frame
        return nil unless fill(deadline)
      end
    end

    private

    def take_frame
      idx = @buf.index("\r\n\r\n")
      return nil unless idx

      header = @buf[0, idx]
      length = header[/Content-Length:\s*(\d+)/i, 1]
      raise "malformed LSP header: #{header.inspect}" if length.nil?

      length = length.to_i
      total = idx + 4 + length
      return nil if @buf.bytesize < total

      body = @buf.byteslice(idx + 4, length)
      @buf = @buf.byteslice(total, @buf.bytesize - total)
      body.force_encoding(Encoding::UTF_8)
    end

    def fill(deadline)
      remaining = deadline - Time.now
      return false if remaining <= 0
      return false unless IO.select([@io], nil, nil, remaining)

      @buf << @io.read_nonblock(65_536)
      true
    rescue IO::WaitReadable
      true
    rescue EOFError, Errno::EIO
      false
    end
  end

  module_function

  def frame(message)
    json = JSON.generate(message)
    "Content-Length: #{json.bytesize}\r\n\r\n#{json}"
  end

  # A minimal project the LSP will actually accept: shard.yml names an Amber
  # stack shard. Without stack coverage the server stays silent and every file
  # looks clean — the exact false green this script exists to make impossible.
  def build_fixture(dir)
    FileUtils.mkdir_p(File.join(dir, "src", "controllers"))
    FileUtils.mkdir_p(File.join(dir, "spec", "controllers"))

    File.write(File.join(dir, "shard.yml"), <<~YAML)
      name: lsp_smoke_app
      version: 0.1.0
      dependencies:
        amber:
          github: amberframework/amber
      targets:
        lsp_smoke_lookup:
          main: src/lsp_smoke_lookup.cr
    YAML

    File.write(File.join(dir, "src", "lsp_smoke_lookup.cr"), <<~CRYSTAL)
      module SmokeLookup
        class User
          # Returns the user's primary key.
          getter id : Int64?
        end
      end
      # Hover target: SmokeLookup::User#id
    CRYSTAL

    # Violating: class name does not end in Controller (amber/controller-naming,
    # error severity) and the action never renders (amber/action-return-type).
    File.write(File.join(dir, "src", "controllers", "users_controller.cr"), <<~CRYSTAL)
      class UsersHandler < Amber::Controller::Base
        def index
          users = ["Alice", "Bob"]
        end
      end
    CRYSTAL
    File.write(File.join(dir, "spec", "controllers", "users_controller_spec.cr"),
               "# spec placeholder\n")

    # Clean: correct suffix, renders, documented, fully typed.
    File.write(File.join(dir, "src", "controllers", "posts_controller.cr"), <<~CRYSTAL)
      # Serves the blog post pages.
      class PostsController < Amber::Controller::Base
        # Renders the list of posts.
        def index : String
          render("index.ecr")
        end
      end
    CRYSTAL
    File.write(File.join(dir, "spec", "controllers", "posts_controller_spec.cr"),
               "# spec placeholder\n")
  end

  def session(server_bin, dir, timeout)
    root_uri = "file://#{dir}"
    bad_uri  = "file://#{dir}/src/controllers/users_controller.cr"
    good_uri = "file://#{dir}/src/controllers/posts_controller.cr"
    good_file_path = File.join(dir, "src", "controllers", "posts_controller.cr")
    clean_content = File.read(good_file_path)
    unsaved_content = clean_content.sub("PostsController", "PostsHandler")
    raise "could not prepare unsaved didChange content" if unsaved_content == clean_content
    published = Hash.new { |hash, uri| hash[uri] = [] }
    status_messages = []
    lookup_uri = "file://#{File.join(dir, "src", "lsp_smoke_lookup.cr")}"

    io = IO.popen([server_bin], "r+", err: File::NULL)
    begin
      io.binmode
      reader = FrameReader.new(io)
      deadline = Time.now + timeout

      initialize_response = request(
        io, reader, 1, "initialize", { "rootUri" => root_uri, "capabilities" => {} },
        deadline, published, status_messages
      )
      notify(io, "initialized", {})
      notify(io, "textDocument/didOpen", {
        "textDocument" => {
          "uri" => bad_uri, "languageId" => "crystal", "version" => 1,
          "text" => File.read(File.join(dir, "src", "controllers", "users_controller.cr"))
        }
      })
      notify(io, "textDocument/didOpen", {
        "textDocument" => {
          "uri" => good_uri, "languageId" => "crystal", "version" => 1,
          "text" => clean_content
        }
      })
      notify(io, "textDocument/didChange", {
        "textDocument" => { "uri" => good_uri, "version" => 2 },
        "contentChanges" => [{ "text" => unsaved_content }]
      })

      workspace_symbol_response = nil
      request_id = 3
      while Time.now < deadline
        workspace_symbol_response = request(
          io, reader, request_id, "workspace/symbol", { "query" => "SmokeLookup::User#id" },
          deadline, published, status_messages
        )
        result_symbols = workspace_symbol_response["result"]
        unless result_symbols.is_a?(Array)
          raise "workspace/symbol returned #{JSON.pretty_generate(workspace_symbol_response)}"
        end
        found_symbol = result_symbols.any? do |symbol|
          symbol["name"].include?("SmokeLookup::User#id")
        end
        break if found_symbol

        request_id += 1
        sleep 0.05
      end

      lookup_source = File.read(File.join(dir, "src", "lsp_smoke_lookup.cr"))
      lookup_line_number = lookup_source.lines.index { |line| line.include?("SmokeLookup::User#id") }
      raise "could not locate hover target in fixture" if lookup_line_number.nil?
      lookup_line = lookup_source.lines[lookup_line_number]
      lookup_character = lookup_line.index("#id") + 2

      hover_response = request(
        io, reader, 40, "textDocument/hover",
        { "textDocument" => { "uri" => lookup_uri }, "position" => { "line" => lookup_line_number, "character" => lookup_character } },
        deadline, published, status_messages
      )
      definition_response = request(
        io, reader, 41, "textDocument/definition",
        { "textDocument" => { "uri" => lookup_uri }, "position" => { "line" => lookup_line_number, "character" => lookup_character } },
        deadline, published, status_messages
      )
      shutdown_response = request(io, reader, 2, "shutdown", {}, deadline, published, status_messages)
      notify(io, "exit", {})
      responses = {
        initialize: initialize_response,
        workspace_symbol: workspace_symbol_response,
        hover: hover_response,
        definition: definition_response,
        shutdown: shutdown_response
      }
    ensure
      begin
        io.close
      rescue StandardError
        nil
      end
    end

    {
      initialized: responses[:initialize] && responses[:initialize]["result"].is_a?(Hash),
      published: published,
      lookup_uri: lookup_uri,
      workspace_symbols: responses[:workspace_symbol] && responses[:workspace_symbol]["result"],
      hover: responses[:hover],
      definition: responses[:definition],
      status_messages: status_messages,
      bad_uri: bad_uri,
      good_uri: good_uri,
      good_file_path: good_file_path,
      disk_content_unchanged: File.read(good_file_path) == clean_content
    }
  end

  def notify(io, method, params)
    io.write(frame("jsonrpc" => "2.0", "method" => method, "params" => params))
    io.flush
  end

  def request(io, reader, id, method, params, deadline, published, status_messages)
    io.write(frame("jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params))
    io.flush

    loop do
      raw = reader.read_frame(deadline)
      raise "timed out waiting for #{method}" if raw.nil?

      message = JSON.parse(raw)
      if message["method"] == "textDocument/publishDiagnostics"
        published[message["params"]["uri"]] << message
      elsif message["method"] == "window/logMessage"
        status_messages << message["params"]["message"]
      end
      return message if message["id"] == id
    end
  end

  def describe(diagnostics)
    diagnostics.map do |d|
      line = d["range"]["start"]["line"].to_i + 1
      sev = SEVERITY.fetch(d["severity"].to_i, d["severity"].to_s)
      "    #{sev} L#{line} [#{d['code']}] #{d['message']}"
    end
  end

  def main(argv)
    server = File.join(Dir.pwd, "bin", "amber-lsp")
    timeout = 15
    keep = false

    until argv.empty?
      case (arg = argv.shift)
      when "--server"  then server = argv.shift.to_s
      when "--timeout" then timeout = argv.shift.to_i
      when "--keep"    then keep = true
      when "-h", "--help"
        puts "usage: lsp_smoke.rb [--server PATH] [--timeout SECONDS] [--keep]"
        return EXIT_OK
      else
        warn "lsp_smoke: unknown argument #{arg.inspect}"
        return EXIT_CANNOT
      end
    end

    unless File.file?(server) && File.executable?(server)
      warn "lsp_smoke: no executable server at #{server}"
      warn "lsp_smoke: build it first — CRYSTAL=crystal-alpha shards-alpha build amber-lsp --release --no-debug"
      return EXIT_CANNOT
    end

    dir = Dir.mktmpdir("amber_lsp_smoke")
    begin
      build_fixture(dir)
      puts "server:  #{server}"
      puts "fixture: #{dir}"
      puts

      result = session(server, dir, timeout)

      unless result[:initialized]
        warn "lsp_smoke: never received a response to `initialize` within #{timeout}s — handshake FAILED."
        return EXIT_CANNOT
      end

      bad_notifications = result[:published][result[:bad_uri]] || []
      good_notifications = result[:published][result[:good_uri]] || []
      bad = bad_notifications[0]
      good = good_notifications[0]
      changed = good_notifications[1]

      if bad.nil? || good.nil? || changed.nil?
        missing = []
        missing << "violating fixture" if bad.nil?
        missing << "clean fixture" if good.nil?
        missing << "didChange fixture" if changed.nil?
        warn "lsp_smoke: no publishDiagnostics for #{missing.join(' and ')} within #{timeout}s."
        warn "lsp_smoke: a silent server is NOT a clean server — treating as could-not-measure."
        return EXIT_CANNOT
      end

      bad_diags = bad["params"]["diagnostics"]
      good_diags = good["params"]["diagnostics"]
      changed_diags = changed["params"]["diagnostics"]

      puts "--- publishDiagnostics: VIOLATING fixture (src/controllers/users_controller.cr) ---"
      puts JSON.pretty_generate(bad)
      puts describe(bad_diags)
      puts
      puts "--- publishDiagnostics: CLEAN fixture (src/controllers/posts_controller.cr) ---"
      puts JSON.pretty_generate(good)
      puts describe(good_diags)
      puts
      puts "--- publishDiagnostics: UNSAVED didChange violation (posts_controller.cr) ---"
      puts JSON.pretty_generate(changed)
      puts describe(changed_diags)
      puts

      workspace_symbols = result[:workspace_symbols] || []
      lookup_symbol = workspace_symbols.find do |symbol|
        symbol["name"].include?("SmokeLookup::User#id")
      end
      hover = result[:hover] && result[:hover]["result"]
      hover_value = hover && hover.dig("contents", "value")
      definition = result[:definition] && result[:definition]["result"]
      definition_location = definition.is_a?(Array) ? definition.first : nil

      puts "--- workspace/symbol: SmokeLookup::User#id ---"
      puts JSON.pretty_generate(lookup_symbol) if lookup_symbol
      puts "--- textDocument/hover: SmokeLookup::User#id ---"
      puts hover_value if hover_value
      puts "--- textDocument/definition: SmokeLookup::User#id ---"
      puts JSON.pretty_generate(definition_location) if definition_location
      puts

      ok = true
      if bad_diags.empty?
        warn "FAIL: violating fixture produced 0 diagnostics (expected >= 1)."
        ok = false
      end
      unless good_diags.empty?
        warn "FAIL: clean fixture produced #{good_diags.size} diagnostic(s) (expected 0)."
        ok = false
      end
      unless changed_diags.any? { |diagnostic| diagnostic["code"] == "amber/controller-naming" }
        warn "FAIL: unsaved didChange content did not produce amber/controller-naming."
        ok = false
      end
      unless result[:disk_content_unchanged]
        warn "FAIL: didChange altered the clean fixture on disk."
        ok = false
      end
      unless lookup_symbol && lookup_symbol.dig("data", "source_layer") == "lsp_smoke_app"
        warn "FAIL: workspace/symbol did not return the fixture API entry from the project layer."
        ok = false
      end
      unless hover_value && hover_value.include?("SmokeLookup::User#id() : Int64 | Nil") &&
             hover_value.include?("Returns the user's primary key.") &&
             hover_value.include?("Layer: lsp_smoke_app") &&
             hover_value.include?("Freshness: unavailable")
        warn "FAIL: hover did not return the indexed signature, documentation, layer, and freshness."
        ok = false
      end
      unless definition_location && definition_location["uri"] == result[:lookup_uri] &&
             definition_location.dig("range", "start", "line") == 3
        warn "FAIL: definition did not return the fixture getter location."
        ok = false
      end

      if ok
        puts "LIVE-FIRE OK: violating=#{bad_diags.size} diagnostic(s), clean=0, didChange=#{changed_diags.size} unsaved diagnostic(s), API workspace/symbol+hover+definition passed, disk=unchanged."
        EXIT_OK
      else
        EXIT_FAILED
      end
    ensure
      FileUtils.rm_rf(dir) unless keep
      puts "fixture kept at #{dir}" if keep
    end
  rescue StandardError => e
    warn "lsp_smoke: could not run (#{e.class}: #{e.message})"
    EXIT_CANNOT
  end
end

exit LSPSmoke.main(ARGV) if $PROGRAM_NAME == __FILE__
