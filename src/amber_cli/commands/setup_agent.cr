require "json"
require "yaml"
require "../core/base_command"
require "../agent/hook_settings"
require "../agent/resolve_compiler_for_agent_loop"
require "../agent/find_agent_hook_ignore_rules"
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
end

module AmberCLI::Commands
  # Installs the optional Claude Code and Codex feedback loop into an Amber V2 app.
  class SetupAgentCommand < AmberCLI::Core::BaseCommand
    AGENT_HOOK_SCRIPT         = {{ read_file("#{__DIR__}/../templates/agent/amber-agent-hook") }}
    MINIMUM_AMBER_LSP_VERSION = AmberCLI::Agent::MINIMUM_AMBER_LSP_VERSION
    GENERATED_HOOK_VERSION    = "4"
    DOCUMENT_START            = "<!-- amber-agent-loop:start -->"
    DOCUMENT_END              = "<!-- amber-agent-loop:end -->"

    def help_description : String
      "Set up the Claude Code and Codex agent loop in an Amber V2 project"
    end

    def setup_command_options
    end

    def execute
      main_file = find_project_main_file
      SetupLSPCommand.new("setup:lsp").execute
      [{".claude/settings.json", true}, {".codex/hooks.json", false}].each do |path, is_claude_settings|
        write_merged_hooks(path, is_claude_settings)
      end
      write_hook_script(main_file)
      write_setup_manifest
      warn_about_ignored_agent_hook_settings
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

    private def write_merged_hooks(path : String, is_claude_settings : Bool) : Nil
      existing_json = File.file?(path) ? File.read(path) : ""
      merged_json = AmberCLI::Agent::MergeAgentHooksIntoSettings.new(existing_json, is_claude_settings).perform
      return if existing_json == merged_json

      Dir.mkdir_p(File.dirname(path))
      File.write(path, merged_json)
      info "Updated: #{path}"
    end

    private def warn_about_ignored_agent_hook_settings : Nil
      ignored_settings = AmberCLI::Agent::FindAgentHookIgnoreRules.new(Dir.current).perform
      ignored_settings.each do |ignored_setting|
        warning "Git ignore rule #{ignored_setting.matching_line} matches #{ignored_setting.path}; agent worktrees will run without those hooks."
      end
    end

    private def write_hook_script(main_file : String) : Nil
      path = ".amber/amber-agent-hook"
      content = AGENT_HOOK_SCRIPT.gsub("__AMBER_MAIN__", main_file)
      Dir.mkdir_p(".amber")
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
          unless updated_section.includes?("amber-lsp lookup 'Type.method'")
            updated_section += "\nBefore using a library API you are not sure of, run `amber-lsp lookup 'Type.method'` or use the LSP tool's workspaceSymbol/hover."
          end
          unless updated_section.includes?("stop and tell the user to run `amber setup:agent`")
            updated_section += "\nThe SessionStart hook reports whether setup is complete. When setup is missing, stop and tell the user to run `amber setup:agent` before editing Crystal files."
          end
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
      Before using a library API you are not sure of, run
      `amber-lsp lookup 'Type.method'` or use the LSP tool's workspaceSymbol/hover.
      The SessionStart hook reports whether setup is complete. When setup is
      missing, stop and tell the user to run `amber setup:agent` before editing
      Crystal files.
      #{DOCUMENT_END}
      MARKDOWN
      prefix = content.empty? ? "" : content.rstrip + "\n\n"
      File.write(path, prefix + section)
      info "Updated: #{path}"
    end
  end
end

AmberCLI::Core::CommandRegistry.register("setup:agent", ["agent"], AmberCLI::Commands::SetupAgentCommand)
