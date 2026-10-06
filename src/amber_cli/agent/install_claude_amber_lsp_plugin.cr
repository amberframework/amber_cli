require "json"
require "./claude_marketplace_settings"

module AmberCLI::Agent
  MINIMUM_AMBER_LSP_VERSION       = "1.0.0"
  CLAUDE_AMBER_LSP_PLUGIN_VERSION = "1.0.0"

  class ClaudeMarketplaceOwner
    include JSON::Serializable

    property name : String

    def initialize(@name : String)
    end
  end

  class ClaudeMarketplacePlugin
    include JSON::Serializable

    property name : String
    property source : String

    def initialize(@name : String, @source : String)
    end
  end

  class ClaudeMarketplaceManifest
    include JSON::Serializable

    property name : String
    property owner : ClaudeMarketplaceOwner
    property plugins : Array(ClaudeMarketplacePlugin)

    def initialize(@name : String, @owner : ClaudeMarketplaceOwner, @plugins : Array(ClaudeMarketplacePlugin))
    end
  end

  class ClaudePluginManifest
    include JSON::Serializable

    property name : String
    property version : String
    property description : String

    def initialize(@name : String, @version : String, @description : String)
    end
  end

  class AmberLSPServerSettings
    include JSON::Serializable

    property command : String
    @[JSON::Field(key: "extensionToLanguage")]
    property extension_to_language : Hash(String, String)

    def initialize(@command : String, @extension_to_language : Hash(String, String))
    end
  end

  class ClaudeLSPServerSettings
    include JSON::Serializable

    property amber : AmberLSPServerSettings

    def initialize(@amber : AmberLSPServerSettings)
    end
  end

  # Merges the Amber directory marketplace into the project's Claude settings.
  class MergeAmberLSPIntoClaudeSettings
    MARKETPLACE_NAME = "amber"
    MARKETPLACE_PATH = "./.amber/claude-marketplace"
    PLUGIN_NAME      = "amber-lsp"

    def initialize(@existing_json : String)
    end

    def perform : String
      settings = @existing_json.empty? ? ClaudeMarketplaceSettings.new : ClaudeMarketplaceSettings.from_json(@existing_json)
      marketplace_sources = settings.extra_known_marketplaces || {} of String => ClaudeMarketplaceDirectorySource
      marketplace_source = marketplace_sources[MARKETPLACE_NAME]? || ClaudeMarketplaceDirectorySource.new
      case source = marketplace_source.source
      when ClaudeMarketplaceDirectorySourceDetails
        source.source = "directory"
        source.path = MARKETPLACE_PATH
      when String
        marketplace_source.source = ClaudeMarketplaceDirectorySourceDetails.new("directory", MARKETPLACE_PATH)
      end
      marketplace_source.path = nil
      marketplace_sources[MARKETPLACE_NAME] = marketplace_source
      settings.extra_known_marketplaces = marketplace_sources

      enabled_plugins = settings.enabled_plugins || {} of String => Bool
      enabled_plugins["#{PLUGIN_NAME}@#{MARKETPLACE_NAME}"] = true
      settings.enabled_plugins = enabled_plugins
      settings.to_pretty_json + "\n"
    end
  end

  # Writes the project-local Claude Code marketplace and Amber LSP plugin.
  class InstallClaudeAmberLSPPlugin
    def perform : Array(String)
      list_of_updated_paths = [] of String
      write_project_file(
        ".amber/claude-marketplace/.claude-plugin/marketplace.json",
        marketplace_manifest.to_pretty_json + "\n",
        list_of_updated_paths,
      )
      write_project_file(
        ".amber/claude-marketplace/amber-lsp/.claude-plugin/plugin.json",
        plugin_manifest.to_pretty_json + "\n",
        list_of_updated_paths,
      )
      write_project_file(
        ".amber/claude-marketplace/amber-lsp/.lsp.json",
        lsp_server_settings.to_pretty_json + "\n",
        list_of_updated_paths,
      )
      update_claude_settings(list_of_updated_paths)
      list_of_updated_paths
    end

    private def marketplace_manifest : ClaudeMarketplaceManifest
      ClaudeMarketplaceManifest.new(
        "amber",
        ClaudeMarketplaceOwner.new("Amber Framework"),
        [ClaudeMarketplacePlugin.new("amber-lsp", "./amber-lsp")],
      )
    end

    private def plugin_manifest : ClaudePluginManifest
      ClaudePluginManifest.new(
        "amber-lsp",
        CLAUDE_AMBER_LSP_PLUGIN_VERSION,
        "Language server for Amber V2 projects.",
      )
    end

    private def lsp_server_settings : ClaudeLSPServerSettings
      server = AmberLSPServerSettings.new("amber-lsp", {".cr" => "crystal"})
      ClaudeLSPServerSettings.new(server)
    end

    private def update_claude_settings(list_of_updated_paths : Array(String)) : Nil
      path = ".claude/settings.json"
      existing_json = File.file?(path) ? File.read(path) : ""
      merged_json = MergeAmberLSPIntoClaudeSettings.new(existing_json).perform
      return if existing_json == merged_json

      Dir.mkdir_p(File.dirname(path))
      File.write(path, merged_json)
      list_of_updated_paths << path
    end

    private def write_project_file(path : String, content : String, list_of_updated_paths : Array(String)) : Nil
      if File.file?(path) && File.read(path) == content
        return
      end

      Dir.mkdir_p(File.dirname(path))
      File.write(path, content)
      list_of_updated_paths << path
    end
  end
end
