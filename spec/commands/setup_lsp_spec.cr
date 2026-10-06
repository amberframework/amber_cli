require "../amber_cli_spec"
require "../../src/amber_cli/commands/setup_lsp"

describe AmberCLI::Commands::SetupLSPCommand do
  it "writes the exact directory marketplace, plugin manifest, and LSP server configuration" do
    SpecHelper.within_temp_directory do
      AmberCLI::Commands::SetupLSPCommand.new("setup:lsp").execute

      expected_marketplace = <<-JSON
      {
        "name": "amber",
        "owner": {
          "name": "Amber Framework"
        },
        "plugins": [
          {
            "name": "amber-lsp",
            "source": "./amber-lsp"
          }
        ]
      }
      JSON
      File.read(".amber/claude-marketplace/.claude-plugin/marketplace.json").should eq(expected_marketplace + "\n")

      expected_plugin = <<-JSON
      {
        "name": "amber-lsp",
        "version": "1.0.0",
        "description": "Language server for Amber V2 projects."
      }
      JSON
      File.read(".amber/claude-marketplace/amber-lsp/.claude-plugin/plugin.json").should eq(expected_plugin + "\n")

      expected_lsp = <<-JSON
      {
        "amber": {
          "command": "amber-lsp",
          "extensionToLanguage": {
            ".cr": "crystal"
          }
        }
      }
      JSON
      File.read(".amber/claude-marketplace/amber-lsp/.lsp.json").should eq(expected_lsp + "\n")
      File.file?(".lsp.json").should be_false
      File.file?(".claude-plugin/plugin.json").should be_false
      File.file?(".amber-lsp.yml").should be_true

      settings = AmberCLI::Agent::ClaudeMarketplaceSettings.from_json(File.read(".claude/settings.json"))
      marketplaces = settings.extra_known_marketplaces || raise("Claude marketplace settings are missing")
      amber_marketplace = marketplaces["amber"]? || raise("Amber marketplace is missing")
      amber_source = amber_marketplace.source
      unless amber_source.is_a?(AmberCLI::Agent::ClaudeMarketplaceDirectorySourceDetails)
        raise "Amber marketplace source must be a nested directory source"
      end
      amber_source.source.should eq("directory")
      amber_source.path.should eq("./.amber/claude-marketplace")
      amber_marketplace.path.should be_nil
      enabled_plugins = settings.enabled_plugins || raise("Claude enabled plugins are missing")
      enabled_plugins["amber-lsp@amber"].should be_true
    end
  end

  it "merges marketplace entries and keeps existing Claude settings and hook data" do
    SpecHelper.within_temp_directory do
      Dir.mkdir_p(".claude")
      File.write(".claude/settings.json", <<-JSON)
      {
        "permissions": {"allow": ["Read"]},
        "extraKnownMarketplaces": {
          "shop": {
            "source": {"source": "directory", "path": "./.plugins/shop", "marker": "keep"},
            "marker": "keep"
          }
        },
        "enabledPlugins": {"shop-plugin@shop": true},
        "hooks": {
          "SessionStart": [{"hooks": [{"type": "command", "command": "existing-session-hook"}]}]
        }
      }
      JSON

      AmberCLI::Commands::SetupLSPCommand.new("setup:lsp").execute

      settings_json = File.read(".claude/settings.json")
      settings = AmberCLI::Agent::ClaudeMarketplaceSettings.from_json(settings_json)
      settings_json.should contain("Read")
      settings_json.should contain("marker")
      settings_json.should contain("keep")
      settings_json.should contain("existing-session-hook")
      marketplaces = settings.extra_known_marketplaces || raise("Claude marketplace settings are missing")
      marketplaces.keys.sort.should eq(["amber", "shop"])
      enabled_plugins = settings.enabled_plugins || raise("Claude enabled plugins are missing")
      enabled_plugins["shop-plugin@shop"].should be_true
      enabled_plugins["amber-lsp@amber"].should be_true
    end
  end
end
