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
    getter checks : Array(DoctorCheck)

    def initialize(@checks : Array(DoctorCheck))
    end

    def exit_code : Int32
      checks.all?(&.ready?) ? 0 : 1
    end

    def to_s(io : IO) : Nil
      checks.each_with_index do |check, index|
        io << '\n' if index > 0
        check.to_s(io)
      end
    end
  end

  class ClaudeProjectTrust
    include JSON::Serializable

    @[JSON::Field(key: "hasTrustDialogAccepted")]
    property has_trust_dialog_accepted : Bool? = nil

    def initialize(@has_trust_dialog_accepted : Bool? = nil)
    end
  end

  class ClaudeUserConfiguration
    include JSON::Serializable

    property projects : Hash(String, ClaudeProjectTrust) = {} of String => ClaudeProjectTrust

    def initialize
    end
  end

  class ClaudePluginStatus
    include JSON::Serializable

    property id : String? = nil
    property enabled : Bool? = nil
    property errors : Array(String)? = nil

    def initialize
    end

    def has_errors? : Bool
      list_of_errors = errors
      list_of_errors ? !list_of_errors.empty? : false
    end
  end

  # Checks the project setup and the trust state each agent stores locally.
  class DoctorCommand < AmberCLI::Core::BaseCommand
    AGENT_HOOK_MODES = %w[session pre post stop]

    def initialize(
      command_name : String,
      @project_root : String = Dir.current,
      @home_directory : String? = ENV["HOME"]?,
      @run_external_checks : Bool = true,
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
      checks = [] of DoctorCheck
      checks << check_project_hooks(".claude/settings.json", true)
      checks << check_project_hooks(".codex/hooks.json", false)
      checks.concat(check_agent_readiness)
      checks.concat(check_claude_trust)
      checks.concat(check_claude_plugin)
      checks.concat(check_codex_trust)
      checks.concat(check_ignored_settings)
      checks << check_api_lookup_index
      DoctorReport.new(checks)
    end

    private def check_project_hooks(settings_path : String, is_claude_settings : Bool) : DoctorCheck
      full_path = File.join(@project_root, settings_path)
      platform = is_claude_settings ? "Claude" : "Codex"
      unless File.file?(full_path)
        return DoctorCheck.new("FAIL", "#{platform} project hooks are missing from #{settings_path}; run `amber setup:agent`.")
      end

      settings = AmberCLI::Agent::HookSettings.from_json(File.read(full_path))
      events = settings.hooks
      unless events
        return DoctorCheck.new("FAIL", "#{platform} project hooks are missing from #{settings_path}; run `amber setup:agent`.")
      end

      missing_modes = [] of String
      AGENT_HOOK_MODES.each do |mode|
        event_groups, matcher = hook_event_groups(events, mode, is_claude_settings)
        found = event_groups.any? do |group|
          group.matcher == matcher && group.hooks.any? do |handler|
            handler.type == "command" && handler.command == ".amber/amber-agent-hook #{mode}"
          end
        end
        missing_modes << mode unless found
      end

      if missing_modes.empty?
        DoctorCheck.new("PASS", "#{platform} project hooks are present and current.")
      else
        DoctorCheck.new("FAIL", "#{platform} project hooks are missing or out of date (#{missing_modes.join(", ")}); run `amber setup:agent`.")
      end
    rescue ex : JSON::ParseException
      DoctorCheck.new("FAIL", "Could not parse #{settings_path}: #{ex.message}; run `amber setup:agent`.")
    rescue ex : IO::Error
      DoctorCheck.new("FAIL", "Could not read #{settings_path}: #{ex.message}; run `amber setup:agent`.")
    end

    private def hook_event_groups(events : AmberCLI::Agent::HookEvents, mode : String, is_claude_settings : Bool) : Tuple(Array(AmberCLI::Agent::HookGroup), String?)
      case mode
      when "session"
        {events.session_start, nil}
      when "pre"
        matcher = is_claude_settings ? AmberCLI::Agent::MergeAgentHooksIntoSettings::CLAUDE_PRE_MATCHER : AmberCLI::Agent::MergeAgentHooksIntoSettings::CODEX_PRE_MATCHER
        {events.pre_tool_use, matcher}
      when "post"
        {events.post_tool_use, AmberCLI::Agent::MergeAgentHooksIntoSettings::POST_MATCHER}
      else
        {events.stop, nil}
      end
    end

    private def check_agent_readiness : Array(DoctorCheck)
      hook_path = File.join(@project_root, ".amber/amber-agent-hook")
      unless @run_external_checks
        return [DoctorCheck.new("SKIP", "Amber binary and project coverage check skipped by the doctor test harness.")]
      end
      unless File::Info.executable?(hook_path)
        return [DoctorCheck.new("FAIL", "The agent readiness hook is missing; run `amber setup:agent`.")]
      end

      exit_code, output, errors = run_process(hook_path, ["check"], @project_root)
      if exit_code == 0
        [DoctorCheck.new("PASS", "Amber agent readiness check passed.")]
      else
        failures = (output + errors).lines.map(&.strip).reject(&.empty?)
        if failures.empty?
          failures << "The Amber agent readiness check failed; run `amber setup:agent` and install a supported amber-lsp release."
        end
        failures.map { |failure| DoctorCheck.new("FAIL", failure) }
      end
    end

    private def check_claude_trust : Array(DoctorCheck)
      unless @run_external_checks
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
      project_trust = configuration.projects[@project_root]?
      if project_trust.try(&.has_trust_dialog_accepted) == true
        [DoctorCheck.new("PASS", "Claude workspace trust is accepted for #{@project_root}.")]
      else
        [DoctorCheck.new("FAIL", "Claude workspace trust is not accepted for #{@project_root}; open the project in Claude Code and accept the trust prompt.")]
      end
    rescue ex : JSON::ParseException
      [DoctorCheck.new("FAIL", "Could not parse Claude workspace trust: #{ex.message}; open the project in Claude Code and accept the trust prompt.")]
    rescue ex : IO::Error
      [DoctorCheck.new("FAIL", "Could not read Claude workspace trust: #{ex.message}; open the project in Claude Code and accept the trust prompt.")]
    end

    private def check_claude_plugin : Array(DoctorCheck)
      unless @run_external_checks
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

      plugins = Array(ClaudePluginStatus).from_json(output)
      plugin = plugins.find { |entry| entry.id == "amber-lsp@amber" }
      if plugin && plugin.enabled == true && !plugin.has_errors?
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
      marketplaces = settings.extra_known_marketplaces
      enabled_plugins = settings.enabled_plugins
      return false unless marketplaces && enabled_plugins.try(&.["amber-lsp@amber"]?) == true

      marketplace = marketplaces["amber"]?
      return false unless marketplace

      source = marketplace.source.as?(AmberCLI::Agent::ClaudeMarketplaceSourceDetails)
      return false unless source.try(&.source) == "directory"
      return false unless source.try(&.path) == "./.amber/claude-marketplace"

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

    private def check_codex_trust : Array(DoctorCheck)
      unless @run_external_checks
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
      expected_keys = codex_agent_hook_keys(settings, File.expand_path(settings_path))
      return [DoctorCheck.new("FAIL", "Codex project hooks are missing; run `amber setup:agent`.")] if expected_keys.empty?

      trusted_hashes = codex_trusted_hashes(File.read(config_path))
      missing_keys = expected_keys.reject do |key|
        hash = trusted_hashes[key]?
        hash && hash.matches?(/\Asha256:[0-9a-fA-F]{64}\z/)
      end
      if missing_keys.empty?
        [DoctorCheck.new("PASS", "Codex project hooks are trusted in #{@project_root}.")]
      else
        [DoctorCheck.new("FAIL", "Codex project hooks are not all trusted; review and trust #{@project_root}/.codex/hooks.json in Codex, then run `amber doctor`.")]
      end
    rescue ex : JSON::ParseException
      [DoctorCheck.new("FAIL", "Could not parse Codex project hooks: #{ex.message}; review and trust the project hooks in Codex.")]
    rescue ex : IO::Error
      [DoctorCheck.new("FAIL", "Could not read Codex hook trust: #{ex.message}; review and trust the project hooks in Codex.")]
    end

    private def codex_agent_hook_keys(settings : AmberCLI::Agent::HookSettings, settings_path : String) : Array(String)
      events = settings.hooks
      return [] of String unless events

      keys = [] of String
      [
        {"session_start", events.session_start},
        {"pre_tool_use", events.pre_tool_use},
        {"post_tool_use", events.post_tool_use},
        {"stop", events.stop},
      ].each do |event_name, groups|
        groups.each_with_index do |group, group_index|
          group.hooks.each_with_index do |handler, handler_index|
            next unless handler.type == "command"
            next unless handler.command.try(&.starts_with?(".amber/amber-agent-hook "))

            keys << "#{settings_path}:#{event_name}:#{group_index}:#{handler_index}"
          end
        end
      end
      keys
    end

    private def codex_trusted_hashes(configuration : String) : Hash(String, String)
      trusted_hashes = {} of String => String
      current_section : String? = nil
      configuration.each_line do |line|
        if section = line.match(/^\[hooks\.state\."(.*)"\]\s*(?:#.*)?$/)
          current_section = section[1]
        elsif line.starts_with?('[')
          current_section = nil
        elsif section_name = current_section
          if trusted_hash = line.match(/^\s*trusted_hash\s*=\s*"([^"]*)"/)
            trusted_hashes[section_name] = trusted_hash[1]
          end
        end
      end
      trusted_hashes
    end

    private def check_ignored_settings : Array(DoctorCheck)
      ignored_settings = AmberCLI::Agent::FindAgentHookIgnoreRules.new(@project_root).perform
      return [DoctorCheck.new("PASS", "Git includes both agent hook settings files in worktrees.")] if ignored_settings.empty?

      ignored_settings.map do |ignored_setting|
        DoctorCheck.new(
          "FAIL",
          "Git ignore rule #{ignored_setting.matching_line} matches #{ignored_setting.path}; remove or narrow that rule so agent worktrees include the hooks.",
        )
      end
    end

    private def check_api_lookup_index : DoctorCheck
      unless @run_external_checks
        return DoctorCheck.new("SKIP", "API lookup status check skipped by the doctor test harness.")
      end

      binary = resolve_amber_lsp
      return DoctorCheck.new("FAIL", "lookup not available in this build") unless binary

      exit_code, output, errors = run_process(binary, ["lookup", "--status"], @project_root)
      combined_output = (output + errors).strip
      if combined_output.empty? || combined_output.matches?(/(?i)(unknown (command|option)|unrecognized|no such command|lookup not available)/)
        return DoctorCheck.new("FAIL", "lookup not available in this build")
      end
      if exit_code == 0 && combined_output.matches?(/(?i)(fresh|current|up.to.date)/) && !combined_output.matches?(/(?i)(stale|out.of.date|missing)/)
        DoctorCheck.new("PASS", "Amber API lookup index is fresh: #{combined_output}")
      else
        detail = combined_output.empty? ? "amber-lsp lookup --status did not confirm a fresh index" : combined_output
        DoctorCheck.new("FAIL", "#{detail}; refresh the API index with `amber-lsp lookup --refresh`.")
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

    private def run_process(command : String, arguments : Array(String), working_directory : String) : Tuple(Int32, String, String)
      output = IO::Memory.new
      errors = IO::Memory.new
      status = Process.run(command, arguments, chdir: working_directory, output: output, error: errors)
      {status.exit_code, output.to_s, errors.to_s}
    rescue ex : File::NotFoundError
      {127, "", ex.message || "executable not found"}
    end
  end
end

AmberCLI::Core::CommandRegistry.register("doctor", Array(String).new, AmberCLI::Commands::DoctorCommand)
