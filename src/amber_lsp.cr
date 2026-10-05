require "json"
require "yaml"
require "uri"

require "./amber_lsp/version"
require "./amber_lsp/rules/severity"
require "./amber_lsp/rules/diagnostic"
require "./amber_lsp/rules/base_rule"
require "./amber_lsp/rules/rule_registry"
require "./amber_lsp/rules/controllers/*"
require "./amber_lsp/rules/jobs/*"
require "./amber_lsp/rules/channels/*"
require "./amber_lsp/rules/pipes/*"
require "./amber_lsp/rules/mailers/*"
require "./amber_lsp/rules/schemas/*"
require "./amber_lsp/rules/file_naming/*"
require "./amber_lsp/rules/routing/*"
require "./amber_lsp/rules/specs/*"
require "./amber_lsp/rules/sockets/*"
require "./amber_lsp/rules/fsdd/*"
require "./amber_lsp/rules/custom_rule"
require "./amber_lsp/document_store"
require "./amber_lsp/project_context"
require "./amber_lsp/configuration"
require "./amber_lsp/analyzer"
require "./amber_lsp/controller"
require "./amber_lsp/server"
require "./amber_lsp/check_file_for_diagnostics"

if ARGV.includes?("--version")
  STDOUT.puts AmberLSP.version_line
  exit 0
elsif ARGV[0]? == "--check"
  file_path = ARGV[1]?
  unless file_path
    STDERR.puts "Usage: amber-lsp --check FILE.cr"
    exit 2
  end
  exit AmberLSP::CheckFileForDiagnostics.new(file_path).perform
else
  AmberLSP::Server.new(STDIN, STDOUT).run
end
