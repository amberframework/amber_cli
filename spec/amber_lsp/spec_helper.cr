require "spec"
require "file_utils"
require "../../src/amber_lsp/version"
require "../../src/amber_lsp/rules/severity"
require "../../src/amber_lsp/rules/diagnostic"
require "../../src/amber_lsp/rules/base_rule"
require "../../src/amber_lsp/rules/rule_registry"
require "../../src/amber_lsp/rules/custom_rule"
require "../../src/amber_lsp/document_store"
require "../../src/amber_lsp/project_context"
require "../../src/amber_lsp/configuration"
require "../../src/amber_lsp/library_rule_packs/describe_library_rule_pack"
require "../../src/amber_lsp/library_rule_packs/load_rule_packs_for_project"
require "../../src/amber_lsp/library_rule_packs/visit_crystal_calls_outside_required_blocks"
require "../../src/amber_lsp/library_rule_packs/grant_tenancy/source_node"
require "../../src/amber_lsp/library_rule_packs/grant_tenancy/grant_tenant_model_declaration"
require "../../src/amber_lsp/library_rule_packs/grant_tenancy/collect_project_grant_tenancy_declarations"
require "../../src/amber_lsp/library_rule_packs/determine_project_rule_pack_state"
require "../../src/amber_lsp/library_rule_packs/grant_tenancy/visit_chainable_unscoped_model_calls"
require "../../src/amber_lsp/library_rule_packs/grant_tenancy/visit_spawn_calls_inside_grant_tenant_blocks"
require "../../src/amber_lsp/library_rule_packs/grant_tenancy/visit_grant_tenant_clear_calls"
require "../../src/amber_lsp/library_rule_packs/grant_tenancy/visit_raw_connection_sql_call_sites"
require "../../src/amber_lsp/library_rule_packs/grant_tenancy/visit_grant_schema_queries_outside_tenant_blocks"
require "../../src/amber_lsp/library_rule_packs/analyze_project_files_with_rule_packs"
require "../../src/amber_lsp/library_rule_packs/print_detected_rule_pack_contexts"
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
  input_data = messages.map { |message| format_lsp_message(message) }.join
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
