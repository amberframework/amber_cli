require "json"
require "yaml"
require "../core/base_command"
require "../../version"
require "./setup_lsp"

module AmberCLI::Agent
  class AgentSetupManifest
    include JSON::Serializable

    property amber_cli_version : String
    property minimum_amber_lsp_version : String
    property generated_hook_version : String

    def initialize(
      @amber_cli_version : String,
      @minimum_amber_lsp_version : String,
      @generated_hook_version : String,
    )
    end
  end

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

    @[JSON::Field(key: "PreToolUse")]
    property pre_tool_use : Array(HookGroup) = [] of HookGroup
    @[JSON::Field(key: "PostToolUse")]
    property post_tool_use : Array(HookGroup) = [] of HookGroup
    @[JSON::Field(key: "Stop")]
    property stop : Array(HookGroup) = [] of HookGroup

    def initialize
    end
  end

  class HookSettings
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    property hooks : HookEvents = HookEvents.new

    def initialize
    end
  end

  # When an agent loop is installed, retain unrelated hook groups and settings.
  class MergeAgentHooksIntoSettings
    MATCHER = "Edit|Write|MultiEdit|NotebookEdit"

    def initialize(@existing_json : String)
    end

    def perform : String
      settings = @existing_json.empty? ? HookSettings.new : HookSettings.from_json(@existing_json)
      add_hook(settings.hooks.pre_tool_use, MATCHER, "bin/amber-agent-hook pre")
      add_hook(settings.hooks.post_tool_use, MATCHER, "bin/amber-agent-hook post")
      add_hook(settings.hooks.stop, nil, "bin/amber-agent-hook stop")
      settings.to_pretty_json + "\n"
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

module AmberCLI::Commands
  # Installs the optional Claude Code and Codex feedback loop into an Amber V2 app.
  class SetupAgentCommand < AmberCLI::Core::BaseCommand
    AGENT_HOOK_SCRIPT = {{ read_file("#{__DIR__}/../templates/agent/amber-agent-hook") }}
    MINIMUM_AMBER_LSP_VERSION = "1.0.0"
    GENERATED_HOOK_VERSION       = "2"
    DOCUMENT_START    = "<!-- amber-agent-loop:start -->"
    DOCUMENT_END      = "<!-- amber-agent-loop:end -->"

    def help_description : String
      "Set up the Claude Code and Codex agent loop in an Amber V2 project"
    end

    def setup_command_options
    end

    def execute
      main_file = find_project_main_file
      SetupLSPCommand.new("setup:lsp").execute
      [".claude/settings.json", ".codex/hooks.json"].each do |path|
        write_merged_hooks(path)
      end
      write_hook_script(main_file)
      write_setup_manifest
      ["CLAUDE.md", "AGENTS.md"].each do |path|
        append_agent_loop_instructions(path)
      end
      success "Amber agent loop installed."
    end

    private def find_project_main_file : String
      unless File.file?("shard.yml")
        raise "Run amber setup:agent from an Amber project with shard.yml"
      end

      manifest = YAML.parse(File.read("shard.yml"))
      targets = manifest["targets"]?.try(&.as_h?)
      first_target = targets.try(&.values.first?)
      target_main = first_target.try(&.["main"]?)
      main_file = target_main.try(&.as_s?)

      unless first_target
        project_name = manifest["name"]?.try(&.as_s?)
        main_file = "src/#{project_name}.cr" if project_name
      end

      unless main_file && main_file.matches?(/\A(?:src\/)?[A-Za-z0-9_\/.-]+\.cr\z/) && !main_file.includes?("..") && File.file?(main_file)
        raise "shard.yml must declare an existing targets.<name>.main or src/<name>.cr Crystal file"
      end
      main_file
    end

    private def write_merged_hooks(path : String) : Nil
      existing_json = File.file?(path) ? File.read(path) : ""
      merged_json = AmberCLI::Agent::MergeAgentHooksIntoSettings.new(existing_json).perform
      return if existing_json == merged_json

      Dir.mkdir_p(File.dirname(path))
      File.write(path, merged_json)
      info "Updated: #{path}"
    end

    private def write_hook_script(main_file : String) : Nil
      path = "bin/amber-agent-hook"
      content = AGENT_HOOK_SCRIPT.gsub("__AMBER_MAIN__", main_file)
      Dir.mkdir_p("bin")
      if !File.file?(path) || File.read(path) != content
        File.write(path, content)
        info "Updated: #{path}"
      end
      File.chmod(path, 0o755)
    end

    private def write_setup_manifest : Nil
      manifest = AmberCLI::Agent::AgentSetupManifest.new(
        AmberCli::VERSION,
        MINIMUM_AMBER_LSP_VERSION,
        GENERATED_HOOK_VERSION,
      )
      Dir.mkdir_p(".amber")
      File.write(".amber/agent_setup.json", manifest.to_pretty_json + "\n")
    end

    private def append_agent_loop_instructions(path : String) : Nil
      content = File.file?(path) ? File.read(path) : ""
      if content.includes?(DOCUMENT_START) && content.includes?(DOCUMENT_END)
        marker_start = content.index(DOCUMENT_START)
        marker_end = content.index(DOCUMENT_END)
        if marker_start && marker_end && marker_start < marker_end
          section = content[marker_start...marker_end]
          updated_section = section.sub("Use `crystal spec --affected`", "Use `crystal-alpha spec --affected`")
          if updated_section != section
            File.write(path, content.sub(section, updated_section))
            info "Updated: #{path}"
          end
          return
        end
      end
      raise "Incomplete Amber agent loop marker in #{path}" if content.includes?(DOCUMENT_START) || content.includes?(DOCUMENT_END)

      section = <<-MARKDOWN
      #{DOCUMENT_START}
      ## Agent loop

      Run `crystal-alpha watch build` after edits. Do not start another watcher.
      Use `crystal-alpha spec --affected` when available. Format Crystal files with
      `crystal-alpha tool format`. The installed hooks hold the watcher during
      edits, check each changed file, and build when the agent stops.
      #{DOCUMENT_END}
      MARKDOWN
      prefix = content.empty? ? "" : content.rstrip + "\n\n"
      File.write(path, prefix + section)
      info "Updated: #{path}"
    end
  end
end

AmberCLI::Core::CommandRegistry.register("setup:agent", ["agent"], AmberCLI::Commands::SetupAgentCommand)
