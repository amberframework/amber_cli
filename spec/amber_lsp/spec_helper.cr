require "spec"
require "file_utils"
require "../../src/amber_lsp/version"
require "../../src/amber_lsp/rules/severity"
require "../../src/amber_lsp/rules/diagnostic"
require "../../src/amber_lsp/rules/base_rule"
require "../../src/amber_lsp/rules/rule_registry"
require "../../src/amber_lsp/document_store"
require "../../src/amber_lsp/project_context"
require "../../src/amber_lsp/configuration"
require "../../src/amber_lsp/analyzer"
require "../../src/amber_lsp/controller"
require "../../src/amber_lsp/server"

def with_tempdir(&)
  dir = File.join(Dir.tempdir, "amber_lsp_test_#{Random::Secure.hex(8)}")
  Dir.mkdir_p(dir)
  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end

def format_lsp_message(message) : String
  json = message.to_json
  "Content-Length: #{json.bytesize}\r\n\r\n#{json}"
end

def run_lsp_session(messages : Array) : Array(JSON::Any)
  input_data = messages.map { |m| format_lsp_message(m) }.join
  input = IO::Memory.new(input_data)
  output = IO::Memory.new

  server = AmberLSP::Server.new(input, output)
  server.run

  output.rewind
  responses = [] of JSON::Any
  while output.pos < output.size
    header = output.gets
    break unless header
    next unless header.starts_with?("Content-Length:")
    length = header.split(":")[1].strip.to_i
    output.gets
    body = Bytes.new(length)
    output.read_fully(body)
    responses << JSON.parse(String.new(body))
  end
  responses
end
