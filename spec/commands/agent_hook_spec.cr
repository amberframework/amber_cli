require "../amber_cli_spec"
require "digest/sha256"
require "../../src/amber_cli/commands/setup_agent"

record AgentHookFixture, project_root : String, hook_path : String, lsp_path : String, lsp_log : String, environment : Hash(String, String)

module AgentHookSpecHelper
  def self.create_ready_project(project_root : String, version : String = "1.0.0", coverage : String = "amber-lsp: covered no diagnostics", coverage_exit : String = "0") : AgentHookFixture
    Dir.mkdir_p("src")
    Dir.mkdir_p(".amber/claude-marketplace/.claude-plugin")
    Dir.mkdir_p(".amber/claude-marketplace/amber-lsp/.claude-plugin")
    Dir.mkdir_p(".claude")
    Dir.mkdir_p(".codex")
    File.write("shard.yml", "name: hook_app\ntargets:\n  app:\n    main: src/app.cr\n")
    File.write("src/app.cr", "puts :ready\n")
    File.write(".amber/agent_setup.json", AmberCLI::Agent::AgentSetupManifest.new(
      AmberCli::VERSION,
      "1.0.0",
      "4",
    ).to_pretty_json + "\n")
    File.write(".amber/claude-marketplace/.claude-plugin/marketplace.json", <<-JSON)
    {
      "name": "amber",
      "owner": {"name": "Amber Framework"},
      "plugins": [{"name": "amber-lsp", "source": "./amber-lsp"}]
    }
    JSON
    File.write(".amber/claude-marketplace/amber-lsp/.claude-plugin/plugin.json", <<-JSON)
    {
      "name": "amber-lsp",
      "version": "1.0.0",
      "description": "Language server for Amber V2 projects."
    }
    JSON
    File.write(".amber/claude-marketplace/amber-lsp/.lsp.json", <<-JSON)
    {
      "amber": {
        "command": "amber-lsp",
        "extensionToLanguage": {".cr": "crystal"}
      }
    }
    JSON
    File.write(".claude/settings.json", <<-JSON)
    {
      "extraKnownMarketplaces": {
        "amber": {
          "source": {"source": "directory", "path": "./.amber/claude-marketplace"}
        }
      },
      "enabledPlugins": {"amber-lsp@amber": true}
    }
    JSON
    claude_settings = AmberCLI::Agent::MergeAgentHooksIntoSettings.new(File.read(".claude/settings.json"), true).perform
    File.write(".claude/settings.json", claude_settings)
    codex_settings = AmberCLI::Agent::MergeAgentHooksIntoSettings.new("", false).perform
    File.write(".codex/hooks.json", codex_settings)

    script = AmberCLI::Commands::SetupAgentCommand::AGENT_HOOK_SCRIPT.gsub("__AMBER_MAIN__", "src/app.cr")
    hook_path = File.join(project_root, ".amber/amber-agent-hook")
    File.write(hook_path, script)
    File.chmod(hook_path, 0o755)

    tools = File.join(project_root, "fake-tools")
    Dir.mkdir_p(tools)
    lsp_path = File.join(tools, "amber-lsp")
    lsp_log = File.join(project_root, "amber-lsp.log")
    write_lsp(lsp_path, version, coverage, coverage_exit)
    environment = {
      "PATH"               => "#{tools}:/usr/bin:/bin",
      "AMBER_LSP_BIN"      => lsp_path,
      "TEST_LSP_LOG"       => lsp_log,
      "TEST_VERSION"       => version,
      "TEST_COVERAGE"      => coverage,
      "TEST_COVERAGE_EXIT" => coverage_exit,
      "TMPDIR"             => File.join(project_root, "hook-cache"),
    }
    Dir.mkdir_p(environment["TMPDIR"])
    AgentHookFixture.new(project_root, hook_path, lsp_path, lsp_log, environment)
  end

  def self.write_lsp(path : String, version : String, coverage : String, coverage_exit : String) : Nil
    content = <<-SH
    #!/bin/sh
    printf '%s\\n' "$*" >> "$TEST_LSP_LOG"
    case "$1" in
      --version) printf 'amber-lsp %s\\n' "$TEST_VERSION"; exit 0 ;;
      --check) printf '%s\\n' "$TEST_COVERAGE"; exit "$TEST_COVERAGE_EXIT" ;;
    esac
    exit 2
    SH
    File.write(path, content)
    File.chmod(path, 0o755)
    write_sidecar(path)
  end

  def self.write_sidecar(binary_path : String) : Nil
    checksum = Digest::SHA256.hexdigest(File.read(binary_path))
    File.write("#{binary_path}.sha256", "#{checksum}  #{binary_path}\n")
  end

  def self.write_legacy_agent_hooks : Nil
    events = AmberCLI::Agent::HookEvents.new
    events.session_start = [legacy_hook_group("session", nil)]
    events.pre_tool_use = [legacy_hook_group("pre", AmberCLI::Agent::MergeAgentHooksIntoSettings::CLAUDE_PRE_MATCHER)]
    events.post_tool_use = [legacy_hook_group("post", "Edit|Write|MultiEdit|NotebookEdit")]
    events.stop = [legacy_hook_group("stop", nil)]

    claude = AmberCLI::Agent::HookSettings.from_json(File.read(".claude/settings.json"))
    claude.hooks = events
    File.write(".claude/settings.json", claude.to_pretty_json + "\n")

    codex_events = AmberCLI::Agent::HookEvents.new
    codex_events.session_start = [legacy_hook_group("session", nil)]
    codex_events.pre_tool_use = [legacy_hook_group("pre", AmberCLI::Agent::MergeAgentHooksIntoSettings::CODEX_PRE_MATCHER)]
    codex_events.post_tool_use = [legacy_hook_group("post", "Edit|Write|MultiEdit|NotebookEdit")]
    codex_events.stop = [legacy_hook_group("stop", nil)]
    codex = AmberCLI::Agent::HookSettings.new
    codex.hooks = codex_events
    File.write(".codex/hooks.json", codex.to_pretty_json + "\n")
  end

  private def self.legacy_hook_group(mode : String, matcher : String?) : AmberCLI::Agent::HookGroup
    hook = AmberCLI::Agent::HookHandler.new("command", ".amber/amber-agent-hook #{mode}")
    AmberCLI::Agent::HookGroup.new(matcher, [hook])
  end

  def self.run_hook(fixture : AgentHookFixture, mode : String, payload : String = "{}", environment_overrides : Hash(String, String) = {} of String => String) : Tuple(Int32, String, String)
    output = IO::Memory.new
    errors = IO::Memory.new
    environment = fixture.environment.merge(environment_overrides)
    status = Process.run(
      fixture.hook_path,
      [mode],
      input: IO::Memory.new(payload),
      output: output,
      error: errors,
      env: environment,
    )
    {status.exit_code, output.to_s, errors.to_s}
  end
end

describe "amber-agent-hook readiness and preflight" do
  it "prints the installed version and API lookup guidance at SessionStart" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root)

      session = AgentHookSpecHelper.run_hook(fixture, "session")

      session[0].should eq(0)
      session[1].should contain("Amber agent setup is OK.")
      session[1].should contain("amber-lsp version: 1.0.0")
      session[1].should contain("Before using a library API you are not sure of, run `amber-lsp lookup 'Type.method'` (or the LSP tool's workspaceSymbol/hover).")
    end
  end

  it "checks a verified binary and project coverage once, then serves the cached result under 300 ms" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root)

      first_check = AgentHookSpecHelper.run_hook(fixture, "check")
      first_check[0].should eq(0)
      first_check[1].should eq("Amber agent setup is ready.\n")
      File.read(fixture.lsp_log).should contain("--version")
      File.read(fixture.lsp_log).should contain("--check src/app.cr")

      previous_calls = File.read(fixture.lsp_log)
      start_time = Time.instant
      cached_check = AgentHookSpecHelper.run_hook(fixture, "check")
      elapsed_milliseconds = (Time.instant - start_time).total_milliseconds
      cached_check[0].should eq(0)
      File.read(fixture.lsp_log).should eq(previous_calls)
      elapsed_milliseconds.should be < 300.0
    end
  end

  it "reports a missing binary in SessionStart and returns the same refusal from a Crystal edit" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root)
      missing_binary = {"AMBER_LSP_BIN" => "/nonexistent"}
      session = AgentHookSpecHelper.run_hook(fixture, "session", "{}", missing_binary)
      preflight = AgentHookSpecHelper.run_hook(
        fixture,
        "pre",
        {"tool_name" => "Edit", "tool_input" => {"file_path" => "/project/src/change.cr"}}.to_json,
        missing_binary,
      )

      session[0].should eq(0)
      session[1].should contain("The amber-lsp binary was not found at /nonexistent or on PATH.")
      session[1].should contain("Do not edit Crystal files yet. Tell the user to run `amber setup:agent` in this project, then continue.")
      preflight[0].should eq(2)
      preflight[2].should eq(session[1])
    end
  end

  it "uses AMBER_LSP_BIN as the selected executable and reports a single missing-binary item" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root)

      check = AgentHookSpecHelper.run_hook(fixture, "check", "{}", {"AMBER_LSP_BIN" => "/nonexistent"})

      check[0].should eq(2)
      check[1].lines.size.should eq(1)
      check[1].should contain("The amber-lsp binary was not found at /nonexistent or on PATH.")
    end
  end

  it "reports cwd-relative generated hook commands as outdated during readiness" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root)
      AgentHookSpecHelper.write_legacy_agent_hooks

      check = AgentHookSpecHelper.run_hook(fixture, "check")

      check[0].should eq(2)
      check[1].should contain("The generated agent hook commands are out of date; run `amber setup:agent`.")
    end
  end

  it "finds amber-lsp on PATH when AMBER_LSP_BIN is unset" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root)
      environment = fixture.environment.dup
      environment.delete("AMBER_LSP_BIN")
      status = Process.run(fixture.hook_path, ["check"], input: IO::Memory.new("{}"), output: IO::Memory.new,
        error: IO::Memory.new, env: environment)

      status.exit_code.should eq(0)
    end
  end

  it "fails a release below the setup minimum before running project coverage" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root, version: "0.9.9")

      check = AgentHookSpecHelper.run_hook(fixture, "check")

      check[0].should eq(2)
      check[1].should contain("The amber-lsp version 0.9.9 is below the required 1.0.0; update amber-lsp.")
      File.read(fixture.lsp_log).should_not contain("--check")
    end
  end

  it "fails closed when the adjacent checksum is missing" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root)
      File.delete("#{fixture.lsp_path}.sha256")

      check = AgentHookSpecHelper.run_hook(fixture, "check")

      check[0].should eq(2)
      check[1].should contain("The amber-lsp checksum is missing or does not match")
      File.read(fixture.lsp_log).should_not contain("--check")
    end
  end

  it "fails closed when the adjacent checksum does not match the binary" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root)
      File.write("#{fixture.lsp_path}.sha256", "#{"0" * 64}  amber-lsp\n")

      check = AgentHookSpecHelper.run_hook(fixture, "check")

      check[0].should eq(2)
      check[1].should contain("The amber-lsp checksum is missing or does not match")
      File.read(fixture.lsp_log).should_not contain("--check")
    end
  end

  it "reads the release checksum from prefix share when no adjacent checksum exists" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root)
      File.delete("#{fixture.lsp_path}.sha256")
      release_prefix = File.join(project_root, "release")
      release_binary = File.join(release_prefix, "bin/amber-lsp")
      Dir.mkdir_p(File.dirname(release_binary))
      File.copy(fixture.lsp_path, release_binary)
      digest = Digest::SHA256.hexdigest(File.read(release_binary))
      checksum_dir = File.join(release_prefix, "share/amber_cli")
      Dir.mkdir_p(checksum_dir)
      File.write(File.join(checksum_dir, "checksums.txt"), "#{digest}  amber-lsp\n")

      check = AgentHookSpecHelper.run_hook(fixture, "check", "{}", {"AMBER_LSP_BIN" => release_binary})

      check[0].should eq(0)
      check[1].should eq("Amber agent setup is ready.\n")
    end
  end

  it "fails coverage when amber-lsp reports declined" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root, coverage: "amber-lsp: declined unsupported file")

      check = AgentHookSpecHelper.run_hook(fixture, "check")

      check[0].should eq(2)
      check[1].should contain("amber-lsp does not cover this project main entry file")
    end
  end

  it "fails when the Claude plugin is stale" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root)
      File.write(".amber/claude-marketplace/amber-lsp/.claude-plugin/plugin.json", %({"name":"amber-lsp","version":"0.9.0","description":"old"}\n))

      check = AgentHookSpecHelper.run_hook(fixture, "check")

      check[0].should eq(2)
      check[1].should contain("The Claude Amber LSP plugin files or settings are missing or out of date")
    end
  end

  it "fails when the Claude marketplace source is not nested under extraKnownMarketplaces" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root)
      File.write(".claude/settings.json", <<-JSON)
      {
        "extraKnownMarketplaces": {
          "amber": {
            "source": "directory",
            "path": "./.amber/claude-marketplace"
          }
        },
        "enabledPlugins": {"amber-lsp@amber": true}
      }
      JSON

      check = AgentHookSpecHelper.run_hook(fixture, "check")

      check[0].should eq(2)
      check[1].should contain("The Claude Amber LSP plugin files or settings are missing or out of date")
    end
  end

  it "invalidates its cache when the setup record changes" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root)
      first_check = AgentHookSpecHelper.run_hook(fixture, "check")
      first_check[0].should eq(0)
      first_calls = File.read(fixture.lsp_log).lines.size
      setup_manifest = AmberCLI::Agent::AgentSetupManifest.new(AmberCli::VERSION, "1.0.0", "4")
      File.write(".amber/agent_setup.json", setup_manifest.to_json + "\n ")

      second_check = AgentHookSpecHelper.run_hook(fixture, "check")

      second_check[0].should eq(0)
      File.read(fixture.lsp_log).lines.size.should be > first_calls
    end
  end

  it "blocks Edit and Write Crystal paths and allows Markdown edits in both setup states" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root)
      payloads = [
        {"tool_name" => "Edit", "tool_input" => {"file_path" => "/project/src/model.cr"}}.to_json,
        {"tool_name" => "Write", "tool_input" => {"file_path" => "/project/src/new_model.cr"}}.to_json,
      ]
      markdown = {"tool_name" => "Edit", "tool_input" => {"file_path" => "/project/README.md"}}.to_json

      payloads.each do |payload|
        AgentHookSpecHelper.run_hook(fixture, "pre", payload)[0].should eq(0)
        AgentHookSpecHelper.run_hook(fixture, "pre", payload, {"AMBER_LSP_BIN" => "/nonexistent"})[0].should eq(2)
      end
      AgentHookSpecHelper.run_hook(fixture, "pre", markdown, {"AMBER_LSP_BIN" => "/nonexistent"})[0].should eq(0)
    end
  end

  it "blocks Codex apply_patch additions and Bash Crystal heredocs while allowing no-write Bash" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root)
      codex_patch = {"tool_name" => "apply_patch", "tool_input" => {"command" => "*** Begin Patch\n*** Add File: src/new_model.cr\n+class NewModel\n+end\n*** End Patch"}}.to_json
      bash_heredoc = {"tool_name" => "Bash", "tool_input" => {"command" => "cat > src/new_model.cr <<'EOF'\nclass NewModel\nend\nEOF"}}.to_json
      no_write_bash = {"tool_name" => "Bash", "tool_input" => {"command" => "crystal-alpha spec"}}.to_json

      [codex_patch, bash_heredoc].each do |payload|
        AgentHookSpecHelper.run_hook(fixture, "pre", payload)[0].should eq(0)
        AgentHookSpecHelper.run_hook(fixture, "pre", payload, {"AMBER_LSP_BIN" => "/nonexistent"})[0].should eq(2)
      end
      AgentHookSpecHelper.run_hook(fixture, "pre", no_write_bash, {"AMBER_LSP_BIN" => "/nonexistent"})[0].should eq(0)
    end
  end

  it "detects Codex tee writes into Crystal files" do
    SpecHelper.within_temp_directory do |project_root|
      fixture = AgentHookSpecHelper.create_ready_project(project_root)
      tee_payload = {"tool_name" => "Bash", "tool_input" => {"command" => "printf 'class NewModel' | tee src/new_model.cr"}}.to_json

      result = AgentHookSpecHelper.run_hook(fixture, "pre", tee_payload, {"AMBER_LSP_BIN" => "/nonexistent"})

      result[0].should eq(2)
      result[2].should contain("The amber-lsp binary was not found")
    end
  end
end
