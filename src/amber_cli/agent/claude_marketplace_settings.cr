require "json"

module AmberCLI::Agent
  class ClaudeMarketplaceDirectorySource
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(emit_null: false)]
    property source : String | ClaudeMarketplaceDirectorySourceDetails = "directory"
    @[JSON::Field(emit_null: false)]
    property path : String? = nil

    def initialize(@source : String | ClaudeMarketplaceDirectorySourceDetails = "directory", @path : String? = nil)
    end
  end

  class ClaudeMarketplaceDirectorySourceDetails
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    property source : String
    property path : String

    def initialize(@source : String, @path : String)
    end
  end

  # Keeps unrelated Claude project settings while merging the Amber marketplace.
  class ClaudeMarketplaceSettings
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(key: "extraKnownMarketplaces", emit_null: false)]
    property extra_known_marketplaces : Hash(String, ClaudeMarketplaceDirectorySource)? = nil
    @[JSON::Field(key: "enabledPlugins", emit_null: false)]
    property enabled_plugins : Hash(String, Bool)? = nil

    def initialize
    end
  end
end
