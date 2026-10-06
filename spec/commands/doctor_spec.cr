require "../amber_cli_spec"
require "../../src/amber_cli/commands/doctor"
require "../../src/amber_cli/agent/install_claude_amber_lsp_plugin"

module DoctorCommandSpecHelper
  def self.create_agent_settings(project_root : String) : String
    Dir.mkdir_p(File.join(project_root, ".claude"))
    Dir.mkdir_p(File.join(project_root, ".codex"))
    claude_settings = AmberCLI::Agent::MergeAgentHooksIntoSettings.new("", true).perform
    codex_settings = AmberCLI::Agent::MergeAgentHooksIntoSettings.new("", false).perform
    File.write(File.join(project_root, ".claude/settings.json"), claude_settings)
    File.write(File.join(project_root, ".codex/hooks.json"), codex_settings)
    codex_settings
  end

  def self.create_legacy_agent_settings(project_root : String) : Nil
    [
      {".claude/settings.json", AmberCLI::Agent::MergeAgentHooksIntoSettings::CLAUDE_PRE_MATCHER},
      {".codex/hooks.json", AmberCLI::Agent::MergeAgentHooksIntoSettings::CODEX_PRE_MATCHER},
    ].each do |settings_path, pre_matcher|
      events = AmberCLI::Agent::HookEvents.new
      events.session_start = [legacy_hook_group("session", nil)]
      events.pre_tool_use = [legacy_hook_group("pre", pre_matcher)]
      events.post_tool_use = [legacy_hook_group("post", "Edit|Write|MultiEdit|NotebookEdit")]
      events.stop = [legacy_hook_group("stop", nil)]
      settings = AmberCLI::Agent::HookSettings.new
      settings.hooks = events
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

      report = AmberCLI::Commands::DoctorCommand.new("doctor", project_root, home_directory, false).perform
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

      report = AmberCLI::Commands::DoctorCommand.new("doctor", project_root, nil, false).perform
      output = report.to_s

      report.exit_code.should eq(1)
      output.should contain("[FAIL] Claude project hooks are missing or out of date")
      output.should contain("[FAIL] Codex project hooks are missing or out of date")
      output.should contain("run `amber setup:agent`.")
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
        "#!/bin/sh\nprintf '%s\\n' 'Amber agent setup is ready.'\nexit 0\n",
      )
      lsp_path = File.join(tools_directory, "amber-lsp")
      DoctorCommandSpecHelper.write_executable(
        lsp_path,
        "#!/bin/sh\n[ \"$1 $2\" = 'lookup --status' ] || exit 2\nprintf '%s\\n' 'Amber API index is fresh'\n",
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
        report = AmberCLI::Commands::DoctorCommand.new("doctor", project_root, home_directory).perform
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
        "#!/bin/sh\nprintf '%s\\n' 'Amber agent setup is ready.'\nexit 0\n",
      )
      lsp_path = File.join(tools_directory, "amber-lsp")
      DoctorCommandSpecHelper.write_executable(
        lsp_path,
        "#!/bin/sh\n[ \"$1 $2\" = 'lookup --status' ] || exit 2\nprintf '%s\\n' 'Amber API index is fresh'\n",
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
        report = AmberCLI::Commands::DoctorCommand.new("doctor", project_root, home_directory).perform
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
