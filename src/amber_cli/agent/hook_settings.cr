require "json"

module AmberCLI::Agent
  class HookHandler
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(key: "type")]
    property handler_type : String? = nil
    property command : String? = nil

    def initialize(@handler_type : String?, @command : String?)
    end
  end

  class HookGroup
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(key: "matcher", emit_null: false)]
    property matcher_pattern : String? = nil
    @[JSON::Field(key: "hooks")]
    property list_of_hooks : Array(HookHandler) = [] of HookHandler

    def initialize(@matcher_pattern : String?, @list_of_hooks : Array(HookHandler))
    end
  end

  class HookEvents
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(key: "SessionStart")]
    property list_of_session_start_hook_groups : Array(HookGroup) = [] of HookGroup
    @[JSON::Field(key: "PreToolUse")]
    property list_of_pre_tool_use_hook_groups : Array(HookGroup) = [] of HookGroup
    @[JSON::Field(key: "PostToolUse")]
    property list_of_post_tool_use_hook_groups : Array(HookGroup) = [] of HookGroup
    @[JSON::Field(key: "Stop")]
    property list_of_stop_hook_groups : Array(HookGroup) = [] of HookGroup

    def initialize
    end
  end

  class ClaudeMarketplaceSource
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(key: "source", emit_null: false)]
    property source_type : String | ClaudeMarketplaceSourceDetails = "directory"
    @[JSON::Field(key: "path", emit_null: false)]
    property directory_path : String? = nil

    def initialize(@source_type : String | ClaudeMarketplaceSourceDetails = "directory", @directory_path : String? = nil)
    end
  end

  class ClaudeMarketplaceSourceDetails
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(key: "source")]
    property source_type : String
    @[JSON::Field(key: "path")]
    property directory_path : String

    def initialize(@source_type : String, @directory_path : String)
    end
  end

  class HookSettings
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(key: "hooks", emit_null: false)]
    property agent_hook_events : HookEvents? = nil
    @[JSON::Field(key: "extraKnownMarketplaces", emit_null: false)]
    property map_of_marketplace_sources_by_name : Hash(String, ClaudeMarketplaceSource)? = nil
    @[JSON::Field(key: "enabledPlugins", emit_null: false)]
    property is_plugin_enabled_by_plugin_id : Hash(String, Bool)? = nil

    def initialize
    end
  end

  # When an agent loop is installed, retain unrelated hook groups and settings.
  class MergeAgentHooksIntoSettings
    CLAUDE_PRE_MATCHER    = "Edit|Write|Bash"
    CODEX_PRE_MATCHER     = "apply_patch|Bash"
    CLAUDE_POST_MATCHER   = "Edit|Write"
    CODEX_POST_MATCHER    = "apply_patch|Bash"
    CLAUDE_COMMAND_PREFIX = %("$CLAUDE_PROJECT_DIR"/.amber/amber-agent-hook )
    CODEX_COMMAND_PREFIX  = %(sh -c 'root=$(git rev-parse --show-toplevel 2>/dev/null) && exec "$root/.amber/amber-agent-hook" )

    def self.generated_command_for(mode : String, is_claude_settings : Bool) : String
      if is_claude_settings
        "#{CLAUDE_COMMAND_PREFIX}#{mode}"
      else
        "#{CODEX_COMMAND_PREFIX}#{mode}'"
      end
    end

    def self.post_matcher_for(is_claude_settings : Bool) : String
      is_claude_settings ? CLAUDE_POST_MATCHER : CODEX_POST_MATCHER
    end

    def initialize(@existing_json : String, @is_claude_settings : Bool = true)
    end

    def perform : String
      settings = @existing_json.empty? ? HookSettings.new : HookSettings.from_json(@existing_json)
      agent_hook_events = settings.agent_hook_events || HookEvents.new
      pre_matcher = @is_claude_settings ? CLAUDE_PRE_MATCHER : CODEX_PRE_MATCHER
      remove_stale_generated_hooks(agent_hook_events)
      add_hook(agent_hook_events.list_of_session_start_hook_groups, nil, self.class.generated_command_for("session", @is_claude_settings))
      add_hook(agent_hook_events.list_of_pre_tool_use_hook_groups, pre_matcher, self.class.generated_command_for("pre", @is_claude_settings))
      add_hook(agent_hook_events.list_of_post_tool_use_hook_groups, self.class.post_matcher_for(@is_claude_settings), self.class.generated_command_for("post", @is_claude_settings))
      add_hook(agent_hook_events.list_of_stop_hook_groups, nil, self.class.generated_command_for("stop", @is_claude_settings))
      settings.agent_hook_events = agent_hook_events
      settings.to_pretty_json + "\n"
    end

    private def remove_stale_generated_hooks(events : HookEvents) : Nil
      {
        {"session", events.list_of_session_start_hook_groups},
        {"pre", events.list_of_pre_tool_use_hook_groups},
        {"post", events.list_of_post_tool_use_hook_groups},
        {"stop", events.list_of_stop_hook_groups},
      }.each do |mode, groups|
        list_of_generated_commands = [
          ".amber/amber-agent-hook #{mode}",
          self.class.generated_command_for(mode, true),
          self.class.generated_command_for(mode, false),
        ]
        groups.each do |group|
          group.list_of_hooks = group.list_of_hooks.reject do |handler|
            handler.handler_type == "command" && list_of_generated_commands.any? { |command| handler.command == command }
          end
        end
      end
    end

    private def add_hook(list_of_hook_groups : Array(HookGroup), matcher : String?, command : String) : Nil
      group = list_of_hook_groups.find { |candidate| candidate.matcher_pattern == matcher }
      unless group
        group = HookGroup.new(matcher, [] of HookHandler)
        list_of_hook_groups << group
      end
      return if group.list_of_hooks.any? { |handler| handler.handler_type == "command" && handler.command == command }

      group.list_of_hooks << HookHandler.new("command", command)
    end
  end
end
