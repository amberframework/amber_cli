require "../amber_cli_spec"
require "../../src/amber_cli/commands/setup_agent"

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
    ["pre", "post", "stop"].each do |event|
      first.scan(/bin\/amber-agent-hook #{event}/).size.should eq(1)
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

      command = AmberCLI::Commands::SetupAgentCommand.new("setup:agent")
      command.execute
      first_claude = File.read(".claude/settings.json")
      first_codex = File.read(".codex/hooks.json")
      first_instructions = File.read("CLAUDE.md")
      first_script = File.read("bin/amber-agent-hook")
      command.execute

      File.read(".claude/settings.json").should eq(first_claude)
      File.read(".codex/hooks.json").should eq(first_codex)
      first_claude.should contain(%("allow": [))
      first_codex.should contain("keep this")
      first_codex.should contain(%("SessionStart": []))
      File.read("CLAUDE.md").should eq(first_instructions)
      File.read("AGENTS.md").scan(/amber-agent-loop:start/).size.should eq(1)
      first_instructions.should contain("# Existing Claude instructions")
      first_script.should contain("build --no-codegen 'src/custom_entry.cr'")
      File.file?(".lsp.json").should be_true
      File.info("bin/amber-agent-hook").permissions.to_i.&(0o111).should_not eq(0)
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
      path = "#{tools}:/usr/bin:/bin"
      hook = File.join(project, "bin/amber-agent-hook")

      run_hook = ->(event : String, payload : String, watch_exit : String, fallback_exit : String) do
        output = IO::Memory.new
        errors = IO::Memory.new
        status = Process.run(hook, [event], input: IO::Memory.new(payload), output: output, error: errors,
          env: {"PATH" => path, "TEST_COMMAND_LOG" => log, "TEST_WATCH_EXIT" => watch_exit, "TEST_FALLBACK_EXIT" => fallback_exit})
        {status.exit_code, output.to_s, errors.to_s}
      end

      run_hook.call("pre", "{}", "0", "0")[0].should eq(0)
      edited_file = File.join(project, "src/my app.cr")
      run_hook.call("post", {"tool_input" => {"file_path" => edited_file}}.to_json, "0", "0")[0].should eq(0)
      calls = File.read(log)
      calls.should contain("compiler watch hold")
      calls.should contain("compiler tool format #{edited_file}")
      calls.should contain("lsp --check #{edited_file}")
      calls.should_not contain("compiler watch build")

      quoted_file = File.join(project, %(src/odd"file.cr))
      File.write(quoted_file, "puts :ok\n")
      run_hook.call("post", {"tool_input" => {"file_path" => quoted_file}}.to_json, "0", "0")[0].should eq(0)
      File.read(log).should contain("compiler tool format #{quoted_file}")

      previous_calls = File.read(log)
      run_hook.call("post", {"tool_input" => {"file_path" => "README.md"}}.to_json, "0", "0")[0].should eq(0)
      File.read(log).should eq(previous_calls)

      another_file = File.join(project, "src/another_file.cr")
      File.write(another_file, "puts :ok\n")
      patch = "*** Begin Patch\n*** Update File: src/my app.cr\n*** Update File: src/another_file.cr\n*** End Patch"
      codex_payload = {"tool_name" => "apply_patch", "tool_input" => {"command" => patch}}.to_json
      run_hook.call("post", codex_payload, "0", "0")[0].should eq(0)
      codex_calls = File.read(log)
      codex_calls.should match(/compiler tool format .*\/src\/another_file\.cr/)
      codex_calls.should match(/lsp --check .*\/src\/another_file\.cr/)

      diagnostic_output = IO::Memory.new
      diagnostic_errors = IO::Memory.new
      diagnostic_status = Process.run(hook, ["post"], input: IO::Memory.new({"tool_input" => {"file_path" => edited_file}}.to_json),
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
end
