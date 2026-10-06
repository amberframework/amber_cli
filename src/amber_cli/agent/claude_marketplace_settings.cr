require "json"

module AmberCLI::Agent
  class ClaudeMarketplaceDirectorySource
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(key: "source", emit_null: false)]
    property source_type : String | ClaudeMarketplaceDirectorySourceDetails = "directory"
    @[JSON::Field(key: "path", emit_null: false)]
    property directory_path : String? = nil

    def initialize(@source_type : String | ClaudeMarketplaceDirectorySourceDetails = "directory", @directory_path : String? = nil)
    end
  end

  class ClaudeMarketplaceDirectorySourceDetails
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(key: "source")]
    property source_type : String
    @[JSON::Field(key: "path")]
    property directory_path : String

    def initialize(@source_type : String, @directory_path : String)
    end
  end

  # Keeps unrelated Claude project settings while merging the Amber marketplace.
  class ClaudeMarketplaceSettings
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(key: "extraKnownMarketplaces", emit_null: false)]
    property map_of_marketplace_sources_by_name : Hash(String, ClaudeMarketplaceDirectorySource)? = nil
    @[JSON::Field(key: "enabledPlugins", emit_null: false)]
    property is_plugin_enabled_by_plugin_id : Hash(String, Bool)? = nil

    def initialize
    end
  end
end
