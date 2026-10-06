require "../amber_cli_spec"
require "digest/sha256"
require "../../src/amber_cli/commands/check_amber_agent_setup_command"
require "../../src/amber_cli/commands/setup_agent_command"
require "../../src/amber_cli/agent/install_claude_amber_lsp_plugin"
require "../../src/amber_cli/agent/agent_setup_manifest"
require "../../src/amber_cli/agent/agent_setup_guidance"

module DoctorCommandSpecHelper
  def self.create_agent_settings(project_root : String) : String
    File.write(File.join(project_root, "shard.yml"), "name: amber_cli\nversion: 0.1.0\n")
    Dir.mkdir_p(File.join(project_root, ".claude"))
    Dir.mkdir_p(File.join(project_root, ".codex"))
    Dir.mkdir_p(File.join(project_root, ".amber"))
    claude_settings = AmberCLI::Agent::MergeAgentHooksIntoSettings.new("", true).perform
    codex_settings = AmberCLI::Agent::MergeAgentHooksIntoSettings.new("", false).perform
    File.write(File.join(project_root, ".claude/settings.json"), claude_settings)
    File.write(File.join(project_root, ".codex/hooks.json"), codex_settings)
    setup_manifest = AmberCLI::Agent::AgentSetupManifest.new(
      "2.0.7",
      "1.0.0",
      AmberCLI::Agent::AgentSetupGuidance::GENERATED_HOOK_VERSION,
    )
    File.write(File.join(project_root, ".amber/agent_setup.json"), setup_manifest.to_pretty_json + "\n")
    File.write(File.join(project_root, ".amber/amber-agent-hook"), AmberCLI::Agent::AgentSetupGuidance::REQUIRED_LOOKUP_INSTRUCTION + "\n")
    agent_loop_instructions = [
      AmberCLI::Agent::AgentSetupGuidance::DOCUMENT_START,
      "## Agent loop",
      AmberCLI::Agent::AgentSetupGuidance::REQUIRED_LOOKUP_INSTRUCTION,
      AmberCLI::Agent::AgentSetupGuidance::DOCUMENT_END,
    ].join("\n") + "\n"
    File.write(File.join(project_root, "CLAUDE.md"), agent_loop_instructions)
    File.write(File.join(project_root, "AGENTS.md"), agent_loop_instructions)
    codex_settings
  end

  def self.create_legacy_agent_settings(project_root : String) : Nil
    [
      {".claude/settings.json", AmberCLI::Agent::MergeAgentHooksIntoSettings::CLAUDE_PRE_MATCHER},
      {".codex/hooks.json", AmberCLI::Agent::MergeAgentHooksIntoSettings::CODEX_PRE_MATCHER},
    ].each do |settings_path, pre_matcher|
      events = AmberCLI::Agent::HookEvents.new
      events.list_of_session_start_hook_groups = [legacy_hook_group("session", nil)]
      events.list_of_pre_tool_use_hook_groups = [legacy_hook_group("pre", pre_matcher)]
      events.list_of_post_tool_use_hook_groups = [legacy_hook_group("post", "Edit|Write|MultiEdit|NotebookEdit")]
      events.list_of_stop_hook_groups = [legacy_hook_group("stop", nil)]
      settings = AmberCLI::Agent::HookSettings.new
      settings.agent_hook_events = events
      File.write(File.join(project_root, settings_path), settings.to_pretty_json + "\n")
    end
  end

  private def self.legacy_hook_group(mode : String, matcher : String?) : AmberCLI::Agent::HookGroup
    hook = AmberCLI::Agent::HookHandler.new("command", ".amber/amber-agent-hook #{mode}")
    AmberCLI::Agent::HookGroup.new(matcher, [hook])
  end

  def self.write_executable(path : String, content : String) : Nil
    Dir.mkdir_p(File.dirname(path))
    File.write(path, content)
    File.chmod(path, 0o755)
  end

  def self.restore_environment(name : String, value : String?) : Nil
    if value
      ENV[name] = value
    else
      ENV.delete(name)
    end
  end
end

describe "amber doctor" do
  it "reports project fixes and exits with status 1 when required hooks are missing" do
    SpecHelper.within_temp_directory do |project_root|
      home_directory = File.join(project_root, "home")
      Dir.mkdir_p(home_directory)

      report = AmberCLI::Commands::CheckAmberAgentSetupCommand.new("doctor", project_root, home_directory, false).perform
      output = report.to_s

      report.exit_code.should eq(1)
      output.should contain("[FAIL] Claude project hooks are missing from .claude/settings.json; run `amber setup:agent`.")
      output.should contain("[FAIL] Codex project hooks are missing from .codex/hooks.json; run `amber setup:agent`.")
      output.should contain("[SKIP] API lookup status check skipped by the doctor test harness.")
    end
  end

  it "reports cwd-relative generated commands as outdated for Claude and Codex" do
    SpecHelper.within_temp_directory do |project_root|
      Dir.mkdir_p(File.join(project_root, ".claude"))
      Dir.mkdir_p(File.join(project_root, ".codex"))
      DoctorCommandSpecHelper.create_legacy_agent_settings(project_root)

      report = AmberCLI::Commands::CheckAmberAgentSetupCommand.new("doctor", project_root, nil, false).perform
      output = report.to_s

      report.exit_code.should eq(1)
      output.should contain("[FAIL] Claude project hooks are missing or out of date")
      output.should contain("[FAIL] Codex project hooks are missing or out of date")
      output.should contain("run `amber setup:agent`.")
    end
  end

  it "reports old generated lookup instructions as outdated" do
    SpecHelper.within_temp_directory do |project_root|
      DoctorCommandSpecHelper.create_agent_settings(project_root)
      Dir.mkdir_p(File.join(project_root, ".amber"))
      old_guidance = "Before using a library API you are not sure of, run `amber-lsp lookup 'Type.method'`."
      File.write(File.join(project_root, ".amber/agent_setup.json"), <<-JSON)
      {"amber_cli_version":"2.0.7","minimum_amber_lsp_version":"1.0.0","generated_hook_version":"5"}
      JSON
      File.write(File.join(project_root, ".amber/amber-agent-hook"), "#!/bin/sh\n#{old_guidance}\n")
      File.write(File.join(project_root, "CLAUDE.md"), "<!-- amber-agent-loop:start -->\n#{old_guidance}\n<!-- amber-agent-loop:end -->\n")
      File.write(File.join(project_root, "AGENTS.md"), "<!-- amber-agent-loop:start -->\n#{old_guidance}\n<!-- amber-agent-loop:end -->\n")

      report = AmberCLI::Commands::CheckAmberAgentSetupCommand.new("doctor", project_root, nil, false).perform

      report.exit_code.should eq(1)
      report.to_s.should contain("[FAIL] Generated agent instructions are out of date; run `amber setup:agent`.")
    end
  end

  it "passes the plain Crystal readiness item when the verified LSP declines Amber coverage" do
    SpecHelper.within_temp_directory do |project_root|
      Dir.mkdir_p(File.join(project_root, "src"))
      File.write(File.join(project_root, "shard.yml"), "name: plain_app\nversion: 0.1.0\n")
      File.write(File.join(project_root, "src/plain_app.cr"), "puts :ok\n")
      AmberCLI::Commands::SetupAgentCommand.new("setup:agent").execute

      home_directory = File.join(project_root, "home")
      tools_directory = File.join(project_root, "tools")
      Dir.mkdir_p(home_directory)
      Dir.mkdir_p(tools_directory)
      lsp_path = File.join(tools_directory, "amber-lsp")
      DoctorCommandSpecHelper.write_executable(lsp_path, <<-SH)
      #!/bin/sh
      case "$1" in
        --version) printf '%s\\n' 'amber-lsp 1.0.0'; exit 0 ;;
        --check) printf '%s\\n' 'amber-lsp: declined project is not an Amber V2 stack project'; exit 2 ;;
        lookup) printf '%s\\n' 'Amber API index is fresh'; exit 0 ;;
      esac
      exit 2
      SH
      checksum = Digest::SHA256.hexdigest(File.read(lsp_path))
      File.write("#{lsp_path}.sha256", "#{checksum}  #{lsp_path}\n")

      previous_path = ENV["PATH"]?
      previous_lsp = ENV["AMBER_LSP_BIN"]?
      ENV["PATH"] = "#{tools_directory}:/usr/bin:/bin"
      ENV["AMBER_LSP_BIN"] = lsp_path
      begin
        report = AmberCLI::Commands::CheckAmberAgentSetupCommand.new("doctor", project_root, home_directory).perform

        report.to_s.should contain("[PASS] plain Crystal project: Amber rules do not apply; lookup and Crystal hints are active")
        report.to_s.should_not contain("amber-lsp does not cover this project main entry file")
      ensure
        DoctorCommandSpecHelper.restore_environment("PATH", previous_path)
        DoctorCommandSpecHelper.restore_environment("AMBER_LSP_BIN", previous_lsp)
      end
    end
  end

  it "reports a ready project with exit status 0 when hooks, trust, plugins, and the API index pass" do
    SpecHelper.within_temp_directory do |project_root|
      home_directory = File.join(project_root, "home")
      tools_directory = File.join(project_root, "tools")
      Dir.mkdir_p(home_directory)
      codex_settings = DoctorCommandSpecHelper.create_agent_settings(project_root)

      File.write(File.join(home_directory, ".claude.json"), {
        "projects" => {
          File.realpath(project_root) => {"hasTrustDialogAccepted" => true},
        },
      }.to_json)
      DoctorCommandSpecHelper.write_executable(
        File.join(tools_directory, "claude"),
        "#!/bin/sh\nprintf '%s\\n' '[{\"id\":\"amber-lsp@amber\",\"enabled\":true,\"projectEnabled\":true,\"errors\":[]}]'\n",
      )
      DoctorCommandSpecHelper.write_executable(File.join(tools_directory, "codex"), "#!/bin/sh\nexit 0\n")
      DoctorCommandSpecHelper.write_executable(
        File.join(project_root, ".amber/amber-agent-hook"),
        "#!/bin/sh\n# #{AmberCLI::Agent::AgentSetupGuidance::REQUIRED_LOOKUP_INSTRUCTION}\nprintf '%s\\n' 'Amber agent setup is ready.'\nexit 0\n",
      )
      lsp_path = File.join(tools_directory, "amber-lsp")
      DoctorCommandSpecHelper.write_executable(
        lsp_path,
        "#!/bin/sh\n[ \"$1 $2\" = 'lookup Dir.mkdir_p' ] || exit 2\nprintf '%s\\n' 'Amber API index is fresh'\n",
      )

      codex_settings_path = File.expand_path(File.join(File.realpath(project_root), ".codex/hooks.json"))
      trusted_entries = %w[session_start pre_tool_use post_tool_use stop].map do |event|
        %([hooks.state."#{codex_settings_path}:#{event}:0:0"]\ntrusted_hash = "sha256:#{"a" * 64}"\n)
      end
      Dir.mkdir_p(File.join(home_directory, ".codex"))
      File.write(File.join(home_directory, ".codex/config.toml"), trusted_entries.join("\n"))

      previous_path = ENV["PATH"]?
      previous_lsp = ENV["AMBER_LSP_BIN"]?
      ENV["PATH"] = "#{tools_directory}:#{previous_path}"
      ENV["AMBER_LSP_BIN"] = lsp_path
      begin
        report = AmberCLI::Commands::CheckAmberAgentSetupCommand.new("doctor", project_root, home_directory).perform
        output = report.to_s

        report.exit_code.should eq(0)
        output.should contain("[PASS] Claude project hooks are present and current.")
        output.should contain("[PASS] Codex project hooks are present and current.")
        output.should contain("[PASS] Claude workspace trust is accepted")
        output.should contain("[PASS] Claude plugin amber-lsp@amber is enabled without errors.")
        output.should contain("[PASS] Codex project hooks are trusted")
        output.should contain("[PASS] Amber API lookup index is fresh")
      ensure
        DoctorCommandSpecHelper.restore_environment("PATH", previous_path)
        DoctorCommandSpecHelper.restore_environment("AMBER_LSP_BIN", previous_lsp)
      end
      codex_settings.should contain("git rev-parse --show-toplevel")
    end
  end

  it "recognizes plugin list entries that have errors" do
    plugin = Array(AmberCLI::Commands::ClaudePluginStatus).from_json(
      %([{"id":"amber-lsp@amber","enabled":true,"errors":["manifest invalid"]}]),
    ).first

    plugin.has_errors?.should be_true
  end

  it "uses the project relative-path marketplace when Claude omits it from plugin list" do
    SpecHelper.within_temp_directory do |project_root|
      home_directory = File.join(project_root, "home")
      tools_directory = File.join(project_root, "tools")
      Dir.mkdir_p(home_directory)
      codex_settings = DoctorCommandSpecHelper.create_agent_settings(project_root)
      AmberCLI::Agent::InstallClaudeAmberLSPPlugin.new.perform

      File.write(File.join(home_directory, ".claude.json"), {
        "projects" => {
          File.realpath(project_root) => {"hasTrustDialogAccepted" => true},
        },
      }.to_json)
      DoctorCommandSpecHelper.write_executable(
        File.join(tools_directory, "claude"),
        "#!/bin/sh\nprintf '%s\\n' '[]'\n",
      )
      DoctorCommandSpecHelper.write_executable(File.join(tools_directory, "codex"), "#!/bin/sh\nexit 0\n")
      DoctorCommandSpecHelper.write_executable(
        File.join(project_root, ".amber/amber-agent-hook"),
        "#!/bin/sh\n# #{AmberCLI::Agent::AgentSetupGuidance::REQUIRED_LOOKUP_INSTRUCTION}\nprintf '%s\\n' 'Amber agent setup is ready.'\nexit 0\n",
      )
      lsp_path = File.join(tools_directory, "amber-lsp")
      DoctorCommandSpecHelper.write_executable(
        lsp_path,
        "#!/bin/sh\n[ \"$1 $2\" = 'lookup Dir.mkdir_p' ] || exit 2\nprintf '%s\\n' 'Amber API index is fresh'\n",
      )

      codex_settings_path = File.expand_path(File.join(File.realpath(project_root), ".codex/hooks.json"))
      trusted_entries = %w[session_start pre_tool_use post_tool_use stop].map do |event|
        %([hooks.state."#{codex_settings_path}:#{event}:0:0"]\ntrusted_hash = "sha256:#{"a" * 64}"\n)
      end
      Dir.mkdir_p(File.join(home_directory, ".codex"))
      File.write(File.join(home_directory, ".codex/config.toml"), trusted_entries.join("\n"))

      previous_path = ENV["PATH"]?
      previous_lsp = ENV["AMBER_LSP_BIN"]?
      ENV["PATH"] = "#{tools_directory}:#{previous_path}"
      ENV["AMBER_LSP_BIN"] = lsp_path
      begin
        report = AmberCLI::Commands::CheckAmberAgentSetupCommand.new("doctor", project_root, home_directory).perform
        output = report.to_s

        report.exit_code.should eq(0)
        output.should contain("[PASS] Claude project plugin is declared in its relative-path marketplace; Claude Code omits it from")
      ensure
        DoctorCommandSpecHelper.restore_environment("PATH", previous_path)
        DoctorCommandSpecHelper.restore_environment("AMBER_LSP_BIN", previous_lsp)
      end
      codex_settings.should contain("git rev-parse --show-toplevel")
    end
  end
end
