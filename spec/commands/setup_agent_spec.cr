require "../amber_cli_spec"
require "../../src/amber_cli/commands/setup_agent"

class RecordSetupAgentMessages < AmberCLI::Commands::SetupAgentCommand
  getter list_of_info_messages : Array(String) = [] of String
  getter list_of_warning_messages : Array(String) = [] of String

  protected def info(message : String)
    @list_of_info_messages << message
  end

  protected def warning(message : String)
    @list_of_warning_messages << message
  end
end

describe "amber setup:agent" do
  it "registers the setup command and short alias" do
    AmberCLI::Core::CommandRegistry.find_command("setup:agent").should_not be_nil
    AmberCLI::Core::CommandRegistry.find_command("agent").should eq(AmberCLI::Core::CommandRegistry.find_command("setup:agent"))
  end

  it "resolves the alpha override, aliases, and stock compiler in order" do
    calls = [] of String
    lookup = ->(command : String) do
      calls << command
      {"acrystal" => "/tools/acrystal", "crystal" => "/tools/crystal"}[command]?
    end

    override = AmberCLI::Agent::ResolveCompilerForAgentLoop.new("/custom/alpha", lookup)
    override.perform.should eq("/custom/alpha")
    calls.should be_empty

    alias_choice = AmberCLI::Agent::ResolveCompilerForAgentLoop.new(nil, lookup)
    alias_choice.perform.should eq("/tools/acrystal")
    alias_choice.stock_compiler?.should be_false
    calls.should eq(["crystal-alpha", "acrystal"])

    stock = AmberCLI::Agent::ResolveCompilerForAgentLoop.new(nil, ->(command : String) { command == "crystal" ? "/tools/crystal" : nil })
    stock.perform.should eq("/tools/crystal")
    stock.stock_compiler?.should be_true
  end

  it "merges hooks while preserving unrelated settings and remains idempotent" do
    existing = %({"permissions":{"allow":["Bash(git status)"]},"hooks":{"PreToolUse":[{"matcher":"Edit|Write|MultiEdit|NotebookEdit","extra":"stay","hooks":[{"type":"command","command":"bin/existing-hook","timeout":42}]}],"SessionStart":[{"hooks":[{"type":"command","command":"bin/start-hook"}]}]}})
    first = AmberCLI::Agent::MergeAgentHooksIntoSettings.new(existing).perform
    second = AmberCLI::Agent::MergeAgentHooksIntoSettings.new(first).perform

    second.should eq(first)
    first.should contain("Bash(git status)")
    first.should contain("bin/existing-hook")
    first.should contain("bin/start-hook")
    first.should contain(%("extra": "stay"))
    first.should contain(%("timeout": 42))
    ["session", "pre", "post", "stop"].each do |event|
      first.scan(/\.amber\/amber-agent-hook #{event}/).size.should eq(1)
    end
    first.should contain(%("Edit|Write|Bash"))
  end

  it "anchors every generated command to the project root for its agent" do
    claude = AmberCLI::Agent::MergeAgentHooksIntoSettings.new("", true).perform
    codex = AmberCLI::Agent::MergeAgentHooksIntoSettings.new("", false).perform

    %w[session pre post stop].each do |mode|
      claude.should contain("\\\"$CLAUDE_PROJECT_DIR\\\"/.amber/amber-agent-hook #{mode}")
      codex.should contain("sh -c 'root=$(git rev-parse --show-toplevel 2>/dev/null) && exec \\\"$root/.amber/amber-agent-hook\\\" #{mode}'")
    end
  end

  it "uses Codex tool names in its pre-edit matcher" do
    settings = AmberCLI::Agent::MergeAgentHooksIntoSettings.new("", false).perform

    settings.should contain(%("apply_patch|Bash"))
    settings.should contain("git rev-parse --show-toplevel")
    settings.should contain(".amber/amber-agent-hook\\\" session")
    settings.should contain(".amber/amber-agent-hook\\\" pre")
  end

  it "matches the PostToolUse tools used by each agent" do
    claude = AmberCLI::Agent::HookSettings.from_json(AmberCLI::Agent::MergeAgentHooksIntoSettings.new("", true).perform)
    codex = AmberCLI::Agent::HookSettings.from_json(AmberCLI::Agent::MergeAgentHooksIntoSettings.new("", false).perform)

    if claude_events = claude.hooks
      claude_events.post_tool_use.map(&.matcher).should eq(["Edit|Write"])
    else
      fail "Claude hooks were not generated"
    end
    if codex_events = codex.hooks
      codex_events.post_tool_use.map(&.matcher).should eq(["apply_patch|Bash"])
    else
      fail "Codex hooks were not generated"
    end
  end

  it "installs the loop into a project without changing existing instructions twice" do
    SpecHelper.within_temp_directory do |project|
      Dir.mkdir_p("src")
      File.write("src/custom_entry.cr", "puts :ok\n")
      File.write("shard.yml", "name: my_app\ntargets:\n  app_entry:\n    main: src/custom_entry.cr\n")
      File.write("CLAUDE.md", "# Existing Claude instructions\n")
      File.write("AGENTS.md", "# Existing Codex instructions\n")
      Dir.mkdir_p(".claude")
      Dir.mkdir_p(".codex")
      File.write(".claude/settings.json", %({"permissions":{"allow":["Read"]}}))
      File.write(".codex/hooks.json", %({"description":"keep this","hooks":{"SessionStart":[]}}))

      command = RecordSetupAgentMessages.new("setup:agent")
      command.execute
      first_claude = File.read(".claude/settings.json")
      first_codex = File.read(".codex/hooks.json")
      first_instructions = File.read("CLAUDE.md")
      first_script = File.read(".amber/amber-agent-hook")
      command.execute

      File.read(".claude/settings.json").should eq(first_claude)
      File.read(".codex/hooks.json").should eq(first_codex)
      first_claude.should contain(%("allow": [))
      first_claude.should contain(".amber/amber-agent-hook session")
      first_codex.should contain("keep this")
      first_codex.should contain("git rev-parse --show-toplevel")
      first_codex.should contain(%("apply_patch|Bash"))
      File.read("CLAUDE.md").should eq(first_instructions)
      File.read("AGENTS.md").scan(/amber-agent-loop:start/).size.should eq(1)
      first_instructions.should contain("# Existing Claude instructions")
      first_instructions.should contain("crystal-alpha spec --affected")
      first_instructions.should contain("amber-lsp lookup 'Type.method'")
      first_instructions.should contain("run `amber setup:agent` before editing")
      first_script.should contain("build --no-codegen 'src/custom_entry.cr'")
      setup_manifest = AmberCLI::Agent::AgentSetupManifest.from_json(File.read(".amber/agent_setup.json"))
      setup_manifest.amber_cli_version.should eq(AmberCli::VERSION)
      setup_manifest.minimum_amber_lsp_version.should eq("1.0.0")
      setup_manifest.generated_hook_version.should eq("4")
      File.file?(".amber/claude-marketplace/amber-lsp/.lsp.json").should be_true
      File.file?(".lsp.json").should be_false
      File.info(".amber/amber-agent-hook").permissions.to_i.&(0o111).should_not eq(0)
      command.list_of_info_messages.count("Updated: .amber/amber-agent-hook").should eq(1)
    end
  end

  it "reports ignore rules that keep tracked hook settings out of worktrees" do
    SpecHelper.within_temp_directory do
      File.write("shard.yml", "name: my_app\n")
      Dir.mkdir_p("src")
      File.write("src/my_app.cr", "puts :ok\n")
      Dir.mkdir_p(".git/info")
      File.write(".gitignore", "/.claude/\n")
      File.write(".git/info/exclude", ".codex/\n")

      command = RecordSetupAgentMessages.new("setup:agent")
      command.execute

      command.list_of_warning_messages.size.should eq(2)
      command.list_of_warning_messages.should contain("Git ignore rule .git/info/exclude:1:.codex/ matches .codex/hooks.json; agent worktrees will run without those hooks.")
      command.list_of_warning_messages.should contain("Git ignore rule .gitignore:1:/.claude/ matches .claude/settings.json; agent worktrees will run without those hooks.")
    end
  end

  it "honors a later ignore negation for hook settings" do
    SpecHelper.within_temp_directory do
      File.write("shard.yml", "name: my_app\n")
      Dir.mkdir_p("src")
      File.write("src/my_app.cr", "puts :ok\n")
      File.write(".gitignore", "/.claude/\n!/.claude/\n")

      command = RecordSetupAgentMessages.new("setup:agent")
      command.execute

      command.list_of_warning_messages.should_not contain("Git ignore rule .gitignore:1:/.claude/")
    end
  end

  it "runs pre, post, and stop against a fake compiler and LSP" do
    SpecHelper.within_temp_directory do |project|
      Dir.mkdir_p("src")
      File.write("src/my app.cr", "puts :ok\n")
      File.write("shard.yml", "name: my_app\ntargets:\n  my_app:\n    main: src/my_app.cr\n")
      File.write("src/my_app.cr", "puts :ok\n")
      AmberCLI::Commands::SetupAgentCommand.new("setup:agent").execute

      tools = File.join(project, "fake-tools")
      Dir.mkdir_p(tools)
      compiler = File.join(tools, "crystal-alpha")
      lsp = File.join(tools, "amber-lsp")
      log = File.join(project, "calls.log")
      File.write(compiler, "#!/bin/sh\nprintf 'compiler %s\\n' \"$*\" >> \"$TEST_COMMAND_LOG\"\nif [ \"$*\" = 'watch build' ]; then\n  [ \"${TEST_WATCH_EXIT:-0}\" -eq 0 ] || echo 'watch build failed'\n  exit \"${TEST_WATCH_EXIT:-0}\"\nfi\n[ \"${TEST_FALLBACK_EXIT:-0}\" -eq 0 ] || echo 'fallback failed'\nexit \"${TEST_FALLBACK_EXIT:-0}\"\n")
      File.write(lsp, "#!/bin/sh\nprintf 'lsp %s\\n' \"$*\" >> \"$TEST_COMMAND_LOG\"\nif [ \"${TEST_LSP_EXIT:-0}\" -ne 0 ]; then\n  echo 'lsp violation'\n  exit \"$TEST_LSP_EXIT\"\nfi\n")
      File.chmod(compiler, 0o755)
      File.chmod(lsp, 0o755)
      File.write(".lsp.json", {"amber" => {"command" => lsp}}.to_pretty_json + "\n")
      path = "#{tools}:/usr/bin:/bin"
      hook = File.join(project, ".amber/amber-agent-hook")

      run_hook = ->(event : String, payload : String, watch_exit : String, fallback_exit : String) do
        output = IO::Memory.new
        errors = IO::Memory.new
        status = Process.run(hook, [event], input: IO::Memory.new(payload), output: output, error: errors,
          env: {"PATH" => path, "TEST_COMMAND_LOG" => log, "TEST_WATCH_EXIT" => watch_exit, "TEST_FALLBACK_EXIT" => fallback_exit})
        {status.exit_code, output.to_s, errors.to_s}
      end

      run_hook.call("pre", "{}", "0", "0")[0].should eq(0)
      edited_file = File.join(project, "src/my app.cr")
      run_hook.call("post", {"tool_name" => "Edit", "tool_input" => {"file_path" => edited_file}}.to_json, "0", "0")[0].should eq(0)
      calls = File.read(log)
      calls.should contain("compiler watch hold")
      calls.should contain("compiler tool format #{edited_file}")
      calls.should contain("lsp --check #{edited_file}")
      calls.should_not contain("compiler watch build")

      quoted_file = File.join(project, %(src/odd"file.cr))
      File.write(quoted_file, "puts :ok\n")
      run_hook.call("post", {"tool_name" => "Edit", "tool_input" => {"file_path" => quoted_file}}.to_json, "0", "0")[0].should eq(0)
      File.read(log).should contain("compiler tool format #{quoted_file}")

      previous_calls = File.read(log)
      run_hook.call("post", {"tool_name" => "Edit", "tool_input" => {"file_path" => "README.md"}}.to_json, "0", "0")[0].should eq(0)
      File.read(log).should eq(previous_calls)

      another_file = File.join(project, "src/another_file.cr")
      File.write(another_file, "puts :ok\n")
      patch = "*** Begin Patch\n*** Update File: src/my app.cr\n*** Update File: src/another_file.cr\n*** End Patch"
      codex_payload = {"tool_name" => "apply_patch", "tool_input" => {"command" => patch}}.to_json
      run_hook.call("post", codex_payload, "0", "0")[0].should eq(0)
      codex_calls = File.read(log)
      codex_calls.should match(/compiler tool format .*\/src\/another_file\.cr/)
      codex_calls.should match(/lsp --check .*\/src\/another_file\.cr/)

      added_file = File.join(File.realpath(project), "src/added_by_patch.cr")
      File.write(added_file, "puts :added_by_patch\n")
      add_patch = "*** Begin Patch\n*** Add File: src/added_by_patch.cr\n+puts :added_by_patch\n*** End Patch"
      add_payload = {"tool_name" => "apply_patch", "tool_input" => {"command" => add_patch}}.to_json
      run_hook.call("post", add_payload, "0", "0")[0].should eq(0)
      add_calls = File.read(log)
      add_calls.should contain("compiler tool format #{added_file}")
      add_calls.should contain("lsp --check #{added_file}")

      bash_file = File.join(File.realpath(project), "src/bash_write.cr")
      File.write(bash_file, "puts :bash_write\n")
      bash_payload = {"tool_name" => "Bash", "tool_input" => {"command" => "cat > src/bash_write.cr <<'EOF'\nputs :bash_write\nEOF"}}.to_json
      run_hook.call("post", bash_payload, "0", "0")[0].should eq(0)
      bash_calls = File.read(log)
      bash_calls.should contain("compiler tool format #{bash_file}")
      bash_calls.should contain("lsp --check #{bash_file}")

      tee_file = File.join(File.realpath(project), "src/tee_write.cr")
      File.write(tee_file, "puts :tee_write\n")
      tee_payload = {"tool_name" => "Bash", "tool_input" => {"command" => "printf 'puts :tee_write' | tee src/tee_write.cr"}}.to_json
      run_hook.call("post", tee_payload, "0", "0")[0].should eq(0)
      tee_calls = File.read(log)
      tee_calls.should contain("compiler tool format #{tee_file}")
      tee_calls.should contain("lsp --check #{tee_file}")

      diagnostic_output = IO::Memory.new
      diagnostic_errors = IO::Memory.new
      diagnostic_status = Process.run(hook, ["post"], input: IO::Memory.new({"tool_name" => "Edit", "tool_input" => {"file_path" => edited_file}}.to_json),
        output: diagnostic_output, error: diagnostic_errors,
        env: {"PATH" => path, "TEST_COMMAND_LOG" => log, "TEST_LSP_EXIT" => "1"})
      diagnostic_status.exit_code.should eq(2)
      diagnostic_errors.to_s.should contain("lsp violation")

      failed = run_hook.call("stop", "{}", "1", "0")
      failed[0].should eq(2)
      failed[2].should contain("watch build failed")
      File.read(log).should_not contain("compiler build --no-codegen")

      fallback = run_hook.call("stop", "{}", "2", "0")
      fallback[0].should eq(0)
      File.read(log).should contain("compiler build --no-codegen src/my_app.cr")

      failed_fallback = run_hook.call("stop", "{}", "2", "1")
      failed_fallback[0].should eq(2)
      failed_fallback[2].should contain("fallback failed")

      run_hook.call("pre", "{}", "0", "2")[0].should eq(0)

      File.rename(compiler, File.join(tools, "acrystal"))
      run_hook.call("pre", "{}", "0", "0")[0].should eq(0)
      File.rename(File.join(tools, "acrystal"), File.join(tools, "crystal"))
      stock_result = run_hook.call("stop", "{}", "0", "0")
      stock_result[0].should eq(0)
      stock_result[2].should contain("fast rebuilds need crystal-alpha")

      override_compiler = File.join(tools, "custom-alpha")
      File.write(override_compiler, "#!/bin/sh\nprintf 'override %s\\n' \"$*\" >> \"$TEST_COMMAND_LOG\"\n")
      File.chmod(override_compiler, 0o755)
      override_status = Process.run(hook, ["pre"], input: IO::Memory.new("{}"), output: IO::Memory.new,
        error: IO::Memory.new, env: {"PATH" => path, "CRYSTAL_ALPHA" => override_compiler, "TEST_COMMAND_LOG" => log})
      override_status.exit_code.should eq(0)
      File.read(log).should contain("override watch hold")
    end
  end

  it "uses the no-targets shard name as the main file" do
    SpecHelper.within_temp_directory do
      Dir.mkdir_p("src")
      File.write("shard.yml", "name: fallback_app\nversion: 0.1.0\n")
      File.write("src/fallback_app.cr", "puts :ok\n")

      AmberCLI::Commands::SetupAgentCommand.new("setup:agent").execute

      File.read(".amber/amber-agent-hook").should contain("build --no-codegen 'src/fallback_app.cr'")
    end
  end

  it "corrects older marked agent instructions on rerun" do
    SpecHelper.within_temp_directory do
      Dir.mkdir_p("src")
      File.write("shard.yml", "name: my_app\n")
      File.write("src/my_app.cr", "puts :ok\n")
      older_instructions = "# Keep this\n\n<!-- amber-agent-loop:start -->\nUse `crystal spec --affected` when available.\n<!-- amber-agent-loop:end -->\n"
      File.write("CLAUDE.md", older_instructions)
      File.write("AGENTS.md", older_instructions)

      command = AmberCLI::Commands::SetupAgentCommand.new("setup:agent")
      command.execute
      first_instructions = File.read("CLAUDE.md")
      first_instructions.should contain("# Keep this")
      first_instructions.should contain("Use `crystal-alpha spec --affected`")
      first_instructions.should_not contain("Use `crystal spec --affected`")
      File.read("AGENTS.md").should eq(first_instructions)

      command.execute
      File.read("CLAUDE.md").should eq(first_instructions)
    end
  end

  it "treats the installed alpha without watch coordination as a build-only compiler" do
    SpecHelper.within_temp_directory do |project|
      Dir.mkdir_p("src")
      File.write("shard.yml", "name: my_app\ntargets:\n  my_app:\n    main: src/my_app.cr\n")
      File.write("src/my_app.cr", "puts :ok\n")
      AmberCLI::Commands::SetupAgentCommand.new("setup:agent").execute

      tools = File.join(project, "fake-tools")
      Dir.mkdir_p(tools)
      compiler = File.join(tools, "crystal-alpha")
      log = File.join(project, "calls.log")
      File.write(compiler, "#!/bin/sh\nprintf 'compiler %s\\n' \"$*\" >> \"$TEST_COMMAND_LOG\"\ncase \"$1\" in\n  watch) echo 'Usage: crystal watch [options] [programfile]'; exit 1 ;;\n  build) exit 0 ;;\nesac\n")
      File.chmod(compiler, 0o755)
      hook = File.join(project, ".amber/amber-agent-hook")
      environment = {"PATH" => "#{tools}:/usr/bin:/bin", "TEST_COMMAND_LOG" => log}

      pre_output = IO::Memory.new
      pre_errors = IO::Memory.new
      pre_status = Process.run(hook, ["pre"], input: IO::Memory.new("{}"), output: pre_output, error: pre_errors, env: environment)
      pre_status.exit_code.should eq(0)
      pre_output.to_s.should_not contain("Usage:")

      stop_output = IO::Memory.new
      stop_errors = IO::Memory.new
      stop_status = Process.run(hook, ["stop"], input: IO::Memory.new("{}"), output: stop_output, error: stop_errors, env: environment)
      stop_status.exit_code.should eq(0)
      stop_errors.to_s.should_not contain("Usage:")
      calls = File.read(log)
      calls.scan(/compiler watch status/).size.should eq(2)
      calls.should_not contain("compiler watch hold")
      calls.should_not contain("compiler watch release")
      calls.should_not contain("compiler watch build")
      calls.should contain("compiler build --no-codegen src/my_app.cr")
    end
  end

  it "blocks post without an LSP and finds a configured LSP when one is available" do
    SpecHelper.within_temp_directory do |project|
      Dir.mkdir_p("src")
      File.write("shard.yml", "name: my_app\ntargets:\n  my_app:\n    main: src/my_app.cr\n")
      File.write("src/my_app.cr", "puts :ok\n")
      AmberCLI::Commands::SetupAgentCommand.new("setup:agent").execute
      File.write(".lsp.json", {"amber" => {"command" => "/missing/amber-lsp"}}.to_pretty_json + "\n")

      tools = File.join(project, "fake-tools")
      Dir.mkdir_p(tools)
      compiler = File.join(tools, "crystal-alpha")
      log = File.join(project, "calls.log")
      File.write(compiler, "#!/bin/sh\nprintf 'compiler %s\\n' \"$*\" >> \"$TEST_COMMAND_LOG\"\nif [ \"${TEST_FORMAT_EXIT:-0}\" -ne 0 ]; then\n  echo 'format failed'\n  exit \"$TEST_FORMAT_EXIT\"\nfi\n")
      File.chmod(compiler, 0o755)
      hook = File.join(project, ".amber/amber-agent-hook")
      payload = {"tool_name" => "Edit", "tool_input" => {"file_path" => "src/my_app.cr"}}.to_json
      File.write("src/other.cr", "puts :other\n")
      patch = "*** Begin Patch\n*** Update File: src/my_app.cr\n*** Update File: src/other.cr\n*** End Patch"
      multiple_files_payload = {"tool_name" => "apply_patch", "tool_input" => {"command" => patch}}.to_json
      environment = {"PATH" => "#{tools}:/usr/bin:/bin", "TEST_COMMAND_LOG" => log}

      errors = IO::Memory.new
      missing_status = Process.run(hook, ["post"], input: IO::Memory.new(multiple_files_payload), output: IO::Memory.new, error: errors, env: environment)
      missing_status.exit_code.should eq(2)
      errors.to_s.should contain("The amber-lsp binary was not found at amber-lsp or on PATH.")
      errors.to_s.should contain("Tell the user to run `amber setup:agent` in this project, then continue.")
      errors.to_s.should_not contain("amber-lsp unavailable")
      File.file?(log).should be_false

      project_lsp = File.join(project, "bin/amber-lsp")
      Dir.mkdir_p("bin")
      File.write(project_lsp, "#!/bin/sh\nprintf 'project-lsp %s\\n' \"$*\" >> \"$TEST_COMMAND_LOG\"\n")
      File.chmod(project_lsp, 0o755)
      errors = IO::Memory.new
      project_status = Process.run(hook, ["post"], input: IO::Memory.new(payload), output: IO::Memory.new, error: errors, env: environment)
      project_status.exit_code.should eq(0)
      errors.to_s.should be_empty
      File.read(log).should contain("project-lsp --check ")

      path_lsp = File.join(tools, "amber-lsp")
      File.write(path_lsp, "#!/bin/sh\nprintf 'path-lsp %s\\n' \"$*\" >> \"$TEST_COMMAND_LOG\"\n")
      File.chmod(path_lsp, 0o755)
      File.write(".lsp.json", {"amber" => {"command" => "amber-lsp"}}.to_pretty_json + "\n")
      project_calls_before = File.read(log).scan(/project-lsp --check /).size
      project_priority = Process.run(hook, ["post"], input: IO::Memory.new(payload), output: IO::Memory.new,
        error: IO::Memory.new, env: environment)
      project_priority.exit_code.should eq(0)
      File.read(log).scan(/project-lsp --check /).size.should eq(project_calls_before + 1)
      File.read(log).should_not contain("path-lsp --check ")

      File.delete(project_lsp)
      File.write(".lsp.json", {"amber" => {"command" => "/missing/amber-lsp"}}.to_pretty_json + "\n")
      path_status = Process.run(hook, ["post"], input: IO::Memory.new(payload), output: IO::Memory.new,
        error: IO::Memory.new, env: environment)
      path_status.exit_code.should eq(0)
      File.read(log).should contain("path-lsp --check ")

      configured_lsp = File.join(tools, "configured-lsp")
      File.write(configured_lsp, "#!/bin/sh\nprintf 'configured-lsp %s\\n' \"$*\" >> \"$TEST_COMMAND_LOG\"\n")
      File.chmod(configured_lsp, 0o755)
      File.write(".lsp.json", {"amber" => {"command" => configured_lsp}}.to_pretty_json + "\n")
      configured_status = Process.run(hook, ["post"], input: IO::Memory.new(payload), output: IO::Memory.new,
        error: IO::Memory.new, env: environment)
      configured_status.exit_code.should eq(0)
      File.read(log).should contain("configured-lsp --check ")

      format_errors = IO::Memory.new
      failed_format = Process.run(hook, ["post"], input: IO::Memory.new(payload), output: IO::Memory.new,
        error: format_errors, env: environment.merge({"TEST_FORMAT_EXIT" => "1"}))
      failed_format.exit_code.should eq(2)
      format_errors.to_s.should contain("format failed")
    end
  end
end
