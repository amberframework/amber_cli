#!/usr/bin/env ruby
# frozen_string_literal: true

# lsp_smoke.rb — live-fire proof that the built `amber-lsp` binary really
# speaks LSP over stdio and really publishes diagnostics.
#
# The Crystal specs under spec/amber_lsp/ exercise the server class in-process
# with an IO::Memory pair. That proves the code, not the binary: it cannot
# catch a stale binary on disk, a broken build, or a server that hangs instead
# of answering. This script spawns the ACTUAL executable, drives a real framed
# stdio session against a throwaway Amber-shaped project, and asserts on the
# `textDocument/publishDiagnostics` notifications that come back.
#
#   scripts/lsp_smoke.rb                       # uses ./bin/amber-lsp
#   scripts/lsp_smoke.rb --server /path/to/amber-lsp
#   scripts/lsp_smoke.rb --timeout 20 --keep   # keep the fixture project
#
# Exit 0 = the violating fixture produced >= 1 diagnostic AND the clean fixture
# produced exactly 0. Exit 1 = live-fire expectations not met. Exit 2 = could
# not run at all (no binary, handshake failure, timeout). A timeout is never
# reported as a pass — "I could not measure it" is not "it is clean".
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

  # A minimal project the LSP will actually accept: ProjectContext.detect only
  # switches diagnostics on when shard.yml has an `amber` DEPENDENCY. Without
  # it the server stays silent and every file looks clean — the exact false
  # green this script exists to make impossible.
  def build_fixture(dir)
    FileUtils.mkdir_p(File.join(dir, "src", "controllers"))
    FileUtils.mkdir_p(File.join(dir, "spec", "controllers"))

    File.write(File.join(dir, "shard.yml"), <<~YAML)
      name: lsp_smoke_app
      version: 0.1.0
      dependencies:
        amber:
          github: amberframework/amber
    YAML

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

    messages = [
      frame("jsonrpc" => "2.0", "id" => 1, "method" => "initialize",
            "params" => { "rootUri" => root_uri, "capabilities" => {} }),
      frame("jsonrpc" => "2.0", "method" => "initialized", "params" => {}),
      frame("jsonrpc" => "2.0", "method" => "textDocument/didOpen",
            "params" => { "textDocument" => {
              "uri" => bad_uri, "languageId" => "crystal", "version" => 1,
              "text" => File.read(File.join(dir, "src", "controllers", "users_controller.cr"))
            } }),
      frame("jsonrpc" => "2.0", "method" => "textDocument/didOpen",
            "params" => { "textDocument" => {
              "uri" => good_uri, "languageId" => "crystal", "version" => 1,
              "text" => File.read(File.join(dir, "src", "controllers", "posts_controller.cr"))
            } }),
      frame("jsonrpc" => "2.0", "id" => 2, "method" => "shutdown"),
      frame("jsonrpc" => "2.0", "method" => "exit")
    ]

    published = {}
    initialized = false

    io = IO.popen([server_bin], "r+", err: File::NULL)
    begin
      io.binmode
      io.write(messages.join)
      io.flush

      reader = FrameReader.new(io)
      deadline = Time.now + timeout

      while published.size < 2 || !initialized
        raw = reader.read_frame(deadline)
        break if raw.nil?

        msg = JSON.parse(raw)
        initialized = true if msg["id"] == 1 && msg.key?("result")
        next unless msg["method"] == "textDocument/publishDiagnostics"

        published[msg["params"]["uri"]] = msg
      end
    ensure
      begin
        io.close
      rescue StandardError
        nil
      end
    end

    { initialized: initialized, published: published, bad_uri: bad_uri, good_uri: good_uri }
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
      warn "lsp_smoke: build it first — CRYSTAL=crystal-alpha shards build amber-lsp"
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

      bad = result[:published][result[:bad_uri]]
      good = result[:published][result[:good_uri]]

      if bad.nil? || good.nil?
        missing = []
        missing << "violating fixture" if bad.nil?
        missing << "clean fixture" if good.nil?
        warn "lsp_smoke: no publishDiagnostics for #{missing.join(' and ')} within #{timeout}s."
        warn "lsp_smoke: a silent server is NOT a clean server — treating as could-not-measure."
        return EXIT_CANNOT
      end

      bad_diags = bad["params"]["diagnostics"]
      good_diags = good["params"]["diagnostics"]

      puts "--- publishDiagnostics: VIOLATING fixture (src/controllers/users_controller.cr) ---"
      puts JSON.pretty_generate(bad)
      puts describe(bad_diags)
      puts
      puts "--- publishDiagnostics: CLEAN fixture (src/controllers/posts_controller.cr) ---"
      puts JSON.pretty_generate(good)
      puts describe(good_diags)
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

      if ok
        puts "LIVE-FIRE OK: violating=#{bad_diags.size} diagnostic(s), clean=0."
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
