require "json"

module AmberCLI::Agent
  class HookHandler
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    property type : String? = nil
    property command : String? = nil

    def initialize(@type : String?, @command : String?)
    end
  end

  class HookGroup
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(emit_null: false)]
    property matcher : String? = nil
    property hooks : Array(HookHandler) = [] of HookHandler

    def initialize(@matcher : String?, @hooks : Array(HookHandler))
    end
  end

  class HookEvents
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(key: "SessionStart")]
    property session_start : Array(HookGroup) = [] of HookGroup
    @[JSON::Field(key: "PreToolUse")]
    property pre_tool_use : Array(HookGroup) = [] of HookGroup
    @[JSON::Field(key: "PostToolUse")]
    property post_tool_use : Array(HookGroup) = [] of HookGroup
    @[JSON::Field(key: "Stop")]
    property stop : Array(HookGroup) = [] of HookGroup

    def initialize
    end
  end

  class ClaudeMarketplaceSource
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(emit_null: false)]
    property source : String | ClaudeMarketplaceSourceDetails = "directory"
    @[JSON::Field(emit_null: false)]
    property path : String? = nil

    def initialize(@source : String | ClaudeMarketplaceSourceDetails = "directory", @path : String? = nil)
    end
  end

  class ClaudeMarketplaceSourceDetails
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    property source : String
    property path : String

    def initialize(@source : String, @path : String)
    end
  end

  class HookSettings
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(emit_null: false)]
    property hooks : HookEvents? = nil
    @[JSON::Field(key: "extraKnownMarketplaces", emit_null: false)]
    property extra_known_marketplaces : Hash(String, ClaudeMarketplaceSource)? = nil
    @[JSON::Field(key: "enabledPlugins", emit_null: false)]
    property enabled_plugins : Hash(String, Bool)? = nil

    def initialize
    end
  end

  # When an agent loop is installed, retain unrelated hook groups and settings.
  class MergeAgentHooksIntoSettings
    CLAUDE_PRE_MATCHER = "Edit|Write|Bash"
    CODEX_PRE_MATCHER  = "apply_patch|Bash"
    POST_MATCHER       = "Edit|Write|MultiEdit|NotebookEdit"

    def initialize(@existing_json : String, @is_claude_settings : Bool = true)
    end

    def perform : String
      settings = @existing_json.empty? ? HookSettings.new : HookSettings.from_json(@existing_json)
      hooks = settings.hooks || HookEvents.new
      pre_matcher = @is_claude_settings ? CLAUDE_PRE_MATCHER : CODEX_PRE_MATCHER
      remove_stale_pre_hook(hooks.pre_tool_use, pre_matcher, ".amber/amber-agent-hook pre")
      add_hook(hooks.session_start, nil, ".amber/amber-agent-hook session")
      add_hook(hooks.pre_tool_use, pre_matcher, ".amber/amber-agent-hook pre")
      add_hook(hooks.post_tool_use, POST_MATCHER, ".amber/amber-agent-hook post")
      add_hook(hooks.stop, nil, ".amber/amber-agent-hook stop")
      settings.hooks = hooks
      settings.to_pretty_json + "\n"
    end

    private def remove_stale_pre_hook(groups : Array(HookGroup), matcher : String, command : String) : Nil
      groups.each do |group|
        next if group.matcher == matcher

        group.hooks = group.hooks.reject do |handler|
          handler.type == "command" && handler.command == command
        end
      end
    end

    private def add_hook(groups : Array(HookGroup), matcher : String?, command : String) : Nil
      group = groups.find { |candidate| candidate.matcher == matcher }
      unless group
        group = HookGroup.new(matcher, [] of HookHandler)
        groups << group
      end
      return if group.hooks.any? { |handler| handler.type == "command" && handler.command == command }

      group.hooks << HookHandler.new("command", command)
    end
  end
end
