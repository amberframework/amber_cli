require "../amber_cli_spec"
require "../../src/amber_cli/commands/setup_lsp"

describe AmberCLI::Commands::SetupLSPCommand do
  it "writes the existing LSP discovery configuration from an Amber project" do
    SpecHelper.within_temp_directory do
      AmberCLI::Commands::SetupLSPCommand.new("setup:lsp").execute

      config = File.read(".lsp.json")
      config.should contain(%("amber"))
      config.should contain(%("extensionToLanguage"))
      config.should contain(%(".cr"))
      File.file?(".claude-plugin/plugin.json").should be_true
      File.file?(".amber-lsp.yml").should be_true
    end
  end
end
