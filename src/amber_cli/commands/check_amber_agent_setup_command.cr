require "json"
require "../core/base_command"
require "../agent/hook_settings"
require "../agent/find_agent_hook_ignore_rules"

module AmberCLI::Commands
  record DoctorCheck, status : String, message : String do
    def ready? : Bool
      status != "FAIL"
    end

    def to_s(io : IO) : Nil
      io << "[" << status << "] " << message
    end
  end

  class DoctorReport
    getter list_of_checks : Array(DoctorCheck)

    def initialize(@list_of_checks : Array(DoctorCheck))
    end

    def exit_code : Int32
      list_of_checks.all?(&.ready?) ? 0 : 1
    end

    def to_s(io : IO) : Nil
      list_of_checks.each_with_index do |check, index|
        io << '\n' if index > 0
        check.to_s(io)
      end
    end
  end

  class ClaudeProjectTrust
    include JSON::Serializable

    @[JSON::Field(key: "hasTrustDialogAccepted")]
    property has_trust_dialog_been_accepted : Bool? = nil

    def initialize(@has_trust_dialog_been_accepted : Bool? = nil)
    end
  end

  class ClaudeUserConfiguration
    include JSON::Serializable

    @[JSON::Field(key: "projects")]
    property map_of_project_trust_by_project_path : Hash(String, ClaudeProjectTrust) = {} of String => ClaudeProjectTrust

    def initialize
    end
  end

  class ClaudePluginStatus
    include JSON::Serializable

    @[JSON::Field(key: "id")]
    property plugin_id : String? = nil
    @[JSON::Field(key: "enabled")]
    property is_plugin_enabled : Bool? = nil
    @[JSON::Field(key: "errors")]
    property list_of_errors : Array(String)? = nil

    def initialize
    end

    def has_errors? : Bool
      current_list_of_errors = list_of_errors
      current_list_of_errors ? !current_list_of_errors.empty? : false
    end
  end

  # Checks the project setup and the trust state each agent stores locally.
  class CheckAmberAgentSetupCommand < AmberCLI::Core::BaseCommand
    AGENT_HOOK_MODES = %w[session pre post stop]

    def initialize(
      command_name : String,
      @project_root : String = Dir.current,
      @home_directory : String? = ENV["HOME"]?,
      @should_run_external_checks : Bool = true,
    )
      super(command_name)
      @project_root = File.realpath(@project_root)
    end

    def help_description : String
      <<-HELP
      Check Amber agent setup and local agent trust

      Usage: amber doctor

      Checks amber-lsp, project hooks, Claude Code registration and trust,
      Codex hook trust, ignored hook settings, and API lookup index status.
      HELP
    end

    def setup_command_options
    end

    def execute
      report = perform
      puts report
      exit(report.exit_code) unless report.exit_code == 0
    end

    def perform : DoctorReport
      list_of_checks = [] of DoctorCheck
      list_of_checks << check_project_hooks(".claude/settings.json", true)
      list_of_checks << check_project_hooks(".codex/hooks.json", false)
      list_of_checks.concat(build_agent_readiness_checks)
      list_of_checks.concat(build_claude_trust_checks)
      list_of_checks.concat(build_claude_plugin_checks)
      list_of_checks.concat(build_codex_trust_checks)
      list_of_checks.concat(build_ignored_settings_checks)
      list_of_checks << check_api_lookup_index
      DoctorReport.new(list_of_checks)
    end

    private def check_project_hooks(settings_path : String, is_claude_settings : Bool) : DoctorCheck
      full_path = File.join(@project_root, settings_path)
      platform = is_claude_settings ? "Claude" : "Codex"
      unless File.file?(full_path)
        return DoctorCheck.new("FAIL", "#{platform} project hooks are missing from #{settings_path}; run `amber setup:agent`.")
      end

      settings = AmberCLI::Agent::HookSettings.from_json(File.read(full_path))
      agent_hook_events = settings.agent_hook_events
      unless agent_hook_events
        return DoctorCheck.new("FAIL", "#{platform} project hooks are missing from #{settings_path}; run `amber setup:agent`.")
      end

      list_of_missing_hook_modes = [] of String
      AGENT_HOOK_MODES.each do |mode|
        list_of_event_groups, matcher = hook_groups_for_event(agent_hook_events, mode, is_claude_settings)
        expected_command = AmberCLI::Agent::MergeAgentHooksIntoSettings.generated_command_for(mode, is_claude_settings)
        legacy_command = ".amber/amber-agent-hook #{mode}"
        found = list_of_event_groups.any? do |group|
          group.matcher_pattern == matcher && group.list_of_hooks.any? do |handler|
            handler.handler_type == "command" && handler.command == expected_command
          end
        end
        has_legacy_command = list_of_event_groups.any? do |group|
          group.list_of_hooks.any? do |handler|
            handler.handler_type == "command" && handler.command == legacy_command
          end
        end
        list_of_missing_hook_modes << mode unless found && !has_legacy_command
      end

      if list_of_missing_hook_modes.empty?
        DoctorCheck.new("PASS", "#{platform} project hooks are present and current.")
      else
        DoctorCheck.new("FAIL", "#{platform} project hooks are missing or out of date (#{list_of_missing_hook_modes.join(", ")}); run `amber setup:agent`.")
      end
    rescue ex : JSON::ParseException
      DoctorCheck.new("FAIL", "Could not parse #{settings_path}: #{ex.message}; run `amber setup:agent`.")
    rescue ex : IO::Error
      DoctorCheck.new("FAIL", "Could not read #{settings_path}: #{ex.message}; run `amber setup:agent`.")
    end

    private def hook_groups_for_event(events : AmberCLI::Agent::HookEvents, mode : String, is_claude_settings : Bool) : Tuple(Array(AmberCLI::Agent::HookGroup), String?)
      case mode
      when "session"
        {events.list_of_session_start_hook_groups, nil}
      when "pre"
        matcher = is_claude_settings ? AmberCLI::Agent::MergeAgentHooksIntoSettings::CLAUDE_PRE_MATCHER : AmberCLI::Agent::MergeAgentHooksIntoSettings::CODEX_PRE_MATCHER
        {events.list_of_pre_tool_use_hook_groups, matcher}
      when "post"
        {events.list_of_post_tool_use_hook_groups, AmberCLI::Agent::MergeAgentHooksIntoSettings.post_matcher_for(is_claude_settings)}
      else
        {events.list_of_stop_hook_groups, nil}
      end
    end

    private def build_agent_readiness_checks : Array(DoctorCheck)
      hook_path = File.join(@project_root, ".amber/amber-agent-hook")
      unless @should_run_external_checks
        return [DoctorCheck.new("SKIP", "Amber binary and project coverage check skipped by the doctor test harness.")]
      end
      unless File::Info.executable?(hook_path)
        return [DoctorCheck.new("FAIL", "The agent readiness hook is missing; run `amber setup:agent`.")]
      end

      exit_code, output, errors = run_process(hook_path, ["check"], @project_root)
      if exit_code == 0
        [DoctorCheck.new("PASS", "Amber agent readiness check passed.")]
      else
        list_of_readiness_failures = (output + errors).lines.map(&.strip).reject(&.empty?)
        if list_of_readiness_failures.empty?
          list_of_readiness_failures << "The Amber agent readiness check failed; run `amber setup:agent` and install a supported amber-lsp release."
        end
        list_of_readiness_failures.map { |failure| DoctorCheck.new("FAIL", failure) }
      end
    end

    private def build_claude_trust_checks : Array(DoctorCheck)
      unless @should_run_external_checks
        return [DoctorCheck.new("SKIP", "Claude workspace trust check skipped by the doctor test harness.")]
      end
      executable = Process.find_executable("claude")
      unless executable
        return [DoctorCheck.new("SKIP", "Claude Code is not installed; workspace trust check skipped.")]
      end
      unless home = @home_directory
        return [DoctorCheck.new("FAIL", "Claude workspace trust could not be checked; set HOME and trust this project in Claude Code.")]
      end

      configuration_path = File.join(home, ".claude.json")
      unless File.file?(configuration_path)
        return [DoctorCheck.new("FAIL", "Claude has no workspace trust record for this project; open it in Claude Code and accept the project trust prompt.")]
      end

      configuration = ClaudeUserConfiguration.from_json(File.read(configuration_path))
      project_trust = configuration.map_of_project_trust_by_project_path[@project_root]?
      if project_trust.try(&.has_trust_dialog_been_accepted) == true
        [DoctorCheck.new("PASS", "Claude workspace trust is accepted for #{@project_root}.")]
      else
        [DoctorCheck.new("FAIL", "Claude workspace trust is not accepted for #{@project_root}; open the project in Claude Code and accept the trust prompt.")]
      end
    rescue ex : JSON::ParseException
      [DoctorCheck.new("FAIL", "Could not parse Claude workspace trust: #{ex.message}; open the project in Claude Code and accept the trust prompt.")]
    rescue ex : IO::Error
      [DoctorCheck.new("FAIL", "Could not read Claude workspace trust: #{ex.message}; open the project in Claude Code and accept the trust prompt.")]
    end

    private def build_claude_plugin_checks : Array(DoctorCheck)
      unless @should_run_external_checks
        return [DoctorCheck.new("SKIP", "Claude plugin runtime check skipped by the doctor test harness.")]
      end
      executable = Process.find_executable("claude")
      unless executable
        return [DoctorCheck.new("SKIP", "Claude Code is not installed; plugin runtime check skipped.")]
      end

      exit_code, output, errors = run_process(executable, ["plugin", "list", "--json"], @project_root)
      unless exit_code == 0
        detail = (errors + output).strip
        detail = "claude plugin list --json failed" if detail.empty?
        return [DoctorCheck.new("FAIL", "#{detail}; run `amber setup:agent`, then resolve Claude plugin errors.")]
      end

      list_of_plugin_statuses = Array(ClaudePluginStatus).from_json(output)
      plugin = list_of_plugin_statuses.find { |entry| entry.plugin_id == "amber-lsp@amber" }
      if plugin && plugin.is_plugin_enabled == true && !plugin.has_errors?
        [DoctorCheck.new("PASS", "Claude plugin amber-lsp@amber is enabled without errors.")]
      elsif plugin.nil? && relative_amber_lsp_plugin_is_declared?
        [DoctorCheck.new("PASS", "Claude project plugin is declared in its relative-path marketplace; Claude Code omits it from claude plugin list --json.")]
      else
        [DoctorCheck.new("FAIL", "Claude plugin amber-lsp@amber is missing, disabled, or has errors; run `amber setup:agent`, then resolve `claude plugin list --json` errors.")]
      end
    rescue ex : JSON::ParseException
      [DoctorCheck.new("FAIL", "Could not parse `claude plugin list --json`: #{ex.message}; run `amber setup:agent` and resolve Claude plugin errors.")]
    end

    private def relative_amber_lsp_plugin_is_declared? : Bool
      settings_path = File.join(@project_root, ".claude/settings.json")
      return false unless File.file?(settings_path)

      settings = AmberCLI::Agent::HookSettings.from_json(File.read(settings_path))
      map_of_marketplace_sources_by_name = settings.map_of_marketplace_sources_by_name
      is_plugin_enabled_by_plugin_id = settings.is_plugin_enabled_by_plugin_id
      return false unless map_of_marketplace_sources_by_name && is_plugin_enabled_by_plugin_id.try(&.["amber-lsp@amber"]?) == true

      marketplace = map_of_marketplace_sources_by_name["amber"]?
      return false unless marketplace

      source = marketplace.source_type.as?(AmberCLI::Agent::ClaudeMarketplaceSourceDetails)
      return false unless source.try(&.source_type) == "directory"
      return false unless source.try(&.directory_path) == "./.amber/claude-marketplace"

      [
        ".amber/claude-marketplace/.claude-plugin/marketplace.json",
        ".amber/claude-marketplace/amber-lsp/.claude-plugin/plugin.json",
        ".amber/claude-marketplace/amber-lsp/.lsp.json",
      ].all? { |path| File.file?(File.join(@project_root, path)) }
    rescue ex : JSON::ParseException
      false
    rescue ex : IO::Error
      false
    end

    private def build_codex_trust_checks : Array(DoctorCheck)
      unless @should_run_external_checks
        return [DoctorCheck.new("SKIP", "Codex project hook trust check skipped by the doctor test harness.")]
      end
      executable = Process.find_executable("codex")
      unless executable
        return [DoctorCheck.new("SKIP", "Codex is not installed; project hook trust check skipped.")]
      end
      unless home = @home_directory
        return [DoctorCheck.new("FAIL", "Codex hook trust could not be checked; set HOME and trust the project hooks in Codex.")]
      end

      settings_path = File.join(@project_root, ".codex/hooks.json")
      config_path = File.join(home, ".codex/config.toml")
      unless File.file?(settings_path)
        return [DoctorCheck.new("FAIL", "Codex project hooks are missing; run `amber setup:agent`.")]
      end
      unless File.file?(config_path)
        return [DoctorCheck.new("FAIL", "Codex has no trust records for project hooks; review and trust them in Codex, then run `amber doctor`.")]
      end

      settings = AmberCLI::Agent::HookSettings.from_json(File.read(settings_path))
      list_of_expected_trust_keys = build_codex_agent_hook_trust_keys(settings, File.expand_path(settings_path))
      return [DoctorCheck.new("FAIL", "Codex project hooks are missing; run `amber setup:agent`.")] if list_of_expected_trust_keys.empty?

      map_of_trusted_hashes = parse_codex_trusted_hashes(File.read(config_path))
      list_of_missing_trust_keys = list_of_expected_trust_keys.reject do |key|
        hash = map_of_trusted_hashes[key]?
        hash && hash.matches?(/\Asha256:[0-9a-fA-F]{64}\z/)
      end
      if list_of_missing_trust_keys.empty?
        [DoctorCheck.new("PASS", "Codex project hooks are trusted in #{@project_root}.")]
      else
        [DoctorCheck.new("FAIL", "Codex project hooks are not all trusted; review and trust #{@project_root}/.codex/hooks.json in Codex, then run `amber doctor`.")]
      end
    rescue ex : JSON::ParseException
      [DoctorCheck.new("FAIL", "Could not parse Codex project hooks: #{ex.message}; review and trust the project hooks in Codex.")]
    rescue ex : IO::Error
      [DoctorCheck.new("FAIL", "Could not read Codex hook trust: #{ex.message}; review and trust the project hooks in Codex.")]
    end

    private def build_codex_agent_hook_trust_keys(settings : AmberCLI::Agent::HookSettings, settings_path : String) : Array(String)
      events = settings.agent_hook_events
      return [] of String unless events

      list_of_codex_agent_hook_trust_keys = [] of String
      hook_command_prefix = AmberCLI::Agent::MergeAgentHooksIntoSettings::CODEX_COMMAND_PREFIX
      [
        {"session_start", events.list_of_session_start_hook_groups},
        {"pre_tool_use", events.list_of_pre_tool_use_hook_groups},
        {"post_tool_use", events.list_of_post_tool_use_hook_groups},
        {"stop", events.list_of_stop_hook_groups},
      ].each do |event_name, groups|
        groups.each_with_index do |group, group_index|
          group.list_of_hooks.each_with_index do |handler, handler_index|
            next unless handler.handler_type == "command"
            next unless handler.command.try(&.starts_with?(hook_command_prefix))

            list_of_codex_agent_hook_trust_keys << "#{settings_path}:#{event_name}:#{group_index}:#{handler_index}"
          end
        end
      end
      list_of_codex_agent_hook_trust_keys
    end

    private def parse_codex_trusted_hashes(configuration : String) : Hash(String, String)
      map_of_trusted_hashes = {} of String => String
      current_section : String? = nil
      configuration.each_line do |line|
        if section = line.match(/^\[hooks\.state\."(.*)"\]\s*(?:#.*)?$/)
          current_section = section[1]
        elsif line.starts_with?('[')
          current_section = nil
        elsif section_name = current_section
          if trusted_hash = line.match(/^\s*trusted_hash\s*=\s*"([^"]*)"/)
            map_of_trusted_hashes[section_name] = trusted_hash[1]
          end
        end
      end
      map_of_trusted_hashes
    end

    private def build_ignored_settings_checks : Array(DoctorCheck)
      list_of_ignored_agent_hook_settings = AmberCLI::Agent::FindAgentHookIgnoreRules.new(@project_root).perform
      return [DoctorCheck.new("PASS", "Git includes both agent hook settings files in worktrees.")] if list_of_ignored_agent_hook_settings.empty?

      list_of_ignored_agent_hook_settings.map do |ignored_setting|
        DoctorCheck.new(
          "FAIL",
          "Git ignore rule #{ignored_setting.matching_line} matches #{ignored_setting.path}; remove or narrow that rule so agent worktrees include the hooks.",
        )
      end
    end

    private def check_api_lookup_index : DoctorCheck
      unless @should_run_external_checks
        return DoctorCheck.new("SKIP", "API lookup status check skipped by the doctor test harness.")
      end

      binary = resolve_amber_lsp
      return DoctorCheck.new("FAIL", "lookup not available in this build") unless binary

      exit_code, output, errors = run_process(binary, ["lookup", "Dir.mkdir_p"], @project_root)
      combined_output = (output + errors).strip
      if combined_output.empty? || combined_output.matches?(/(?i)(unknown (command|option)|unrecognized|no such command|lookup not available)/)
        return DoctorCheck.new("FAIL", "lookup not available in this build")
      end
      if exit_code == 0 && combined_output.matches?(/(?i)(fresh|current|up.to.date)/) && !combined_output.matches?(/(?i)(stale|out.of.date|missing)/)
        DoctorCheck.new("PASS", "Amber API lookup index is fresh: #{combined_output}")
      else
        detail = combined_output.empty? ? "amber-lsp lookup 'Dir.mkdir_p' did not confirm a fresh index" : combined_output
        DoctorCheck.new("FAIL", "#{detail}; check the API index with `amber-lsp lookup 'Dir.mkdir_p'`.")
      end
    end

    private def resolve_amber_lsp : String?
      if requested_binary = ENV["AMBER_LSP_BIN"]?
        if requested_binary.includes?('/')
          full_path = File.expand_path(requested_binary, @project_root)
          return full_path if File::Info.executable?(full_path)
          return nil
        end
        return Process.find_executable(requested_binary)
      end
      Process.find_executable("amber-lsp")
    end

    private def run_process(command : String, list_of_arguments : Array(String), working_directory : String) : Tuple(Int32, String, String)
      output = IO::Memory.new
      errors = IO::Memory.new
      status = Process.run(command, list_of_arguments, chdir: working_directory, output: output, error: errors)
      {status.exit_code, output.to_s, errors.to_s}
    rescue ex : File::NotFoundError
      {127, "", ex.message || "executable not found"}
    end
  end
end

AmberCLI::Core::CommandRegistry.register("doctor", Array(String).new, AmberCLI::Commands::CheckAmberAgentSetupCommand)
