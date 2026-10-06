require "../spec_helper"
require "../../../src/amber_lsp/lookup/hint_command"

describe AmberLSP::Lookup::RunHintCommand do
  it "prints matching project and dependency card hints from compiler output" do
    with_hint_cli_project do |project|
      input = IO::Memory.new("undefined method 'save'\nundefined method 'lookup'\n")
      output = IO::Memory.new
      error = IO::Memory.new
      exit_code = AmberLSP::Lookup::RunHintCommand.new(
        ["--root", project],
        input,
        output,
        error,
      ).perform

      exit_code.should eq(0)
      output.to_s.lines.should eq([
        "hint: Persist the model with its supported save operation. [fixture_project@1.5.0]",
        "  right: user.save",
        "hint: Use the lookup helper defined on the widget's query module. [example@0.3.5]",
        "  right: Example::Widget.lookup(\"widget-1\")",
      ])
      error.to_s.should be_empty
    end
  end

  it "prints interpolated numbered and named captures with the card version" do
    with_capture_hint_cli_project do |project|
      input = IO::Memory.new("undefined method 'lookup' for Example::Widget\n")
      output = IO::Memory.new
      code = AmberLSP::Lookup::RunHintCommand.new(
        ["--root", project],
        input,
        output,
        IO::Memory.new,
      ).perform

      code.should eq(0)
      output.to_s.lines.should eq([
        "hint: Call lookup on Example::Widget. [fixture_project@1.5.0]",
        "  right: Example::Widget.lookup(\"widget-1\")",
        "hint: Use lookup with the widget. [fixture_project@1.5.0]",
        "  right: Example::Widget.lookup(\"widget-2\")",
      ])
    end
  end

  it "exits successfully without output when no card hint matches" do
    with_hint_cli_project do |project|
      input = IO::Memory.new("undefined method 'unlisted'\n")
      output = IO::Memory.new
      code = AmberLSP::Lookup::RunHintCommand.new(
        ["--root", project],
        input,
        output,
        IO::Memory.new,
      ).perform

      code.should eq(0)
      output.to_s.should be_empty
    end
  end

  it "prints usage and exits successfully for --help" do
    output = IO::Memory.new
    code = AmberLSP::Lookup::RunHintCommand.new(
      ["--help"],
      IO::Memory.new,
      output,
      IO::Memory.new,
    ).perform

    code.should eq(0)
    output.to_s.should contain("Usage: amber-lsp hint [--root DIR]")
    output.to_s.should contain("compiler output from stdin")
  end

  it "uses the compiled Crystal language card for a plain project" do
    with_tempdir do |project|
      input = IO::Memory.new("undefined method 'to_sym' for String\n")
      output = IO::Memory.new
      code = AmberLSP::Lookup::RunHintCommand.new(
        ["--root", project],
        input,
        output,
        IO::Memory.new,
      ).perform

      code.should eq(0)
      output.to_s.lines.should eq([
        "hint: Crystal String has no `to_sym`; keep values as String, or call `to_s` when converting a Symbol to String. [crystal@1.21.0]",
        "  right: name.to_s",
      ])
    end
  end
end

private def with_hint_cli_project(&)
  with_tempdir do |project|
    fixture_root = File.join(Dir.current, "spec", "fixtures", "api_lookup", "cards")
    File.write(
      File.join(project, "shard.yml"),
      "name: fixture_project\nversion: 1.5.0\ndependencies:\n  example:\n    github: example/library\n",
    )
    File.write(
      File.join(project, "shard.lock"),
      "shards:\n  example:\n    version: 0.3.5\n",
    )
    Dir.mkdir_p(File.join(project, "lib", "example"))
    FileUtils.cp_r(File.join(fixture_root, "project", ".amber-lsp"), project)
    FileUtils.cp_r(
      File.join(fixture_root, "library", ".amber-lsp"),
      File.join(project, "lib", "example"),
    )
    yield project
  end
end

private def with_capture_hint_cli_project(&)
  with_tempdir do |project|
    fixture_root = File.join(Dir.current, "spec", "fixtures", "api_lookup", "capture_cards")
    File.write(File.join(project, "shard.yml"), "name: fixture_project\nversion: 1.5.0\n")
    FileUtils.cp_r(File.join(fixture_root, ".amber-lsp"), project)
    yield project
  end
end
