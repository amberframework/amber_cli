require "json"
require "./claude_marketplace_settings"

module AmberCLI::Agent
  MINIMUM_AMBER_LSP_VERSION       = "1.0.0"
  CLAUDE_AMBER_LSP_PLUGIN_VERSION = "1.0.0"

  class ClaudeMarketplaceOwner
    include JSON::Serializable

    @[JSON::Field(key: "name")]
    property owner_name : String

    def initialize(@owner_name : String)
    end
  end

  class ClaudeMarketplacePlugin
    include JSON::Serializable

    @[JSON::Field(key: "name")]
    property plugin_name : String
    @[JSON::Field(key: "source")]
    property source_location : String

    def initialize(@plugin_name : String, @source_location : String)
    end
  end

  class ClaudeMarketplaceManifest
    include JSON::Serializable

    @[JSON::Field(key: "name")]
    property marketplace_name : String
    @[JSON::Field(key: "owner")]
    property marketplace_owner : ClaudeMarketplaceOwner
    @[JSON::Field(key: "plugins")]
    property list_of_plugins : Array(ClaudeMarketplacePlugin)

    def initialize(@marketplace_name : String, @marketplace_owner : ClaudeMarketplaceOwner, @list_of_plugins : Array(ClaudeMarketplacePlugin))
    end
  end

  class ClaudePluginManifest
    include JSON::Serializable

    @[JSON::Field(key: "name")]
    property plugin_name : String
    property version : String
    property description : String

    def initialize(@plugin_name : String, @version : String, @description : String)
    end
  end

  class AmberLSPServerSettings
    include JSON::Serializable

    @[JSON::Field(key: "command")]
    property server_command : String
    @[JSON::Field(key: "extensionToLanguage")]
    property language_by_file_extension : Hash(String, String)

    def initialize(@server_command : String, @language_by_file_extension : Hash(String, String))
    end
  end

  class ClaudeLSPServerSettings
    include JSON::Serializable

    @[JSON::Field(key: "amber")]
    property amber_lsp_server_settings : AmberLSPServerSettings

    def initialize(@amber_lsp_server_settings : AmberLSPServerSettings)
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
      map_of_marketplace_sources_by_name = settings.map_of_marketplace_sources_by_name || {} of String => ClaudeMarketplaceDirectorySource
      marketplace_source = map_of_marketplace_sources_by_name[MARKETPLACE_NAME]? || ClaudeMarketplaceDirectorySource.new
      case source = marketplace_source.source_type
      when ClaudeMarketplaceDirectorySourceDetails
        source.source_type = "directory"
        source.directory_path = MARKETPLACE_PATH
      when String
        marketplace_source.source_type = ClaudeMarketplaceDirectorySourceDetails.new("directory", MARKETPLACE_PATH)
      end
      marketplace_source.directory_path = nil
      map_of_marketplace_sources_by_name[MARKETPLACE_NAME] = marketplace_source
      settings.map_of_marketplace_sources_by_name = map_of_marketplace_sources_by_name

      is_plugin_enabled_by_plugin_id = settings.is_plugin_enabled_by_plugin_id || {} of String => Bool
      is_plugin_enabled_by_plugin_id["#{PLUGIN_NAME}@#{MARKETPLACE_NAME}"] = true
      settings.is_plugin_enabled_by_plugin_id = is_plugin_enabled_by_plugin_id
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
