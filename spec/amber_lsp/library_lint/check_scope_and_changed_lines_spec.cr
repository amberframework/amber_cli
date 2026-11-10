require "./spec_helper"

private RAISE_SOURCE = %(def failing_call\n  raise "failure"\nend\n)

private def build_owner_spec(owner_declaration : String) : String
  <<-SPEC
  describe #{owner_declaration} do
    describe "#process" do
      it "returns a positive value" do
        Widget.new.process(1).should eq(1)
      end

      context "at the boundary" do
        it "accepts zero" do
          Widget.new.process(0).should eq(0)
        end
      end

      context "just past the boundary" do
        it "rejects a negative value" do
          expect_raises(ArgumentError) { Widget.new.process(-1) }
        end
      end
    end
  end
  SPEC
end

private def build_widget_source(changed_expression : String) : String
  "module Sample\n  class Widget\n    def process(value : Int32) : Int32\n      if value > 0\n        #{changed_expression}\n      else\n        0\n      end\n    end\n  end\nend\n"
end

private def run_collar_check(owner_declaration : String) : String
  run_collar_check_with_spec(build_owner_spec(owner_declaration))
end

private def run_collar_check_with_spec(spec_source : String) : String
  _exit_code, output, _error_output = run_library_lint_with_git_changes(
    {"src/widget.cr" => build_widget_source("value"), "spec/widget_spec.cr" => spec_source},
    {"src/widget.cr" => build_widget_source("value + 1")},
  )
  output
end

# Commits *relative_path*, appends a string raise, and checks from *root_directory*.
private def run_changed_line_check(
  relative_path : String,
  root_directory : String = ".",
  list_of_git_settings : Array(Tuple(String, String)) = [] of Tuple(String, String),
) : Tuple(Int32, String, String)
  result : Tuple(Int32, String, String) = {0, "", ""}
  with_tempdir do |repository_path|
    write_library_lint_fixture_files(repository_path, {relative_path => "def stable_call\n  1\nend\n"})
    Dir.mkdir_p(File.join(repository_path, root_directory, "src"))
    run_library_lint_git_command(repository_path, ["init", "-q"])
    run_library_lint_git_command(repository_path, ["config", "user.name", "Spec Runner"])
    run_library_lint_git_command(repository_path, ["config", "user.email", "spec@example.invalid"])
    list_of_git_settings.each do |setting_name, setting_value|
      run_library_lint_git_command(repository_path, ["config", setting_name, setting_value])
    end
    run_library_lint_git_command(repository_path, ["add", "-A"])
    run_library_lint_git_command(repository_path, ["commit", "-q", "-m", "base fixture"])
    File.open(File.join(repository_path, relative_path), "a", &.print(RAISE_SOURCE))

    output = IO::Memory.new
    error_output = IO::Memory.new
    project_root = File.expand_path(root_directory, repository_path)
    exit_code = AmberLSP::LibraryLint::RunLibraryLintCheck.new(
      ["--since", "HEAD", "--root", project_root],
      output,
      error_output,
    ).perform
    result = {exit_code, output.to_s, error_output.to_s}
  end
  result
end

describe AmberLSP::LibraryLint::CheckLibraryProjectFiles do
  describe "#perform" do
    it "applies a source rule to a nested source file" do
      _exit_code, output, _error_output = run_library_lint_for_files({"src/nested/sample.cr" => RAISE_SOURCE}, ["--all"])
      output.should contain("library/typed-raise")
    end

    context "at the boundary: the file sits directly under src" do
      it "applies the source rule" do
        _exit_code, output, _error_output = run_library_lint_for_files({"src/sample.cr" => RAISE_SOURCE}, ["--all"])
        output.should contain("library/typed-raise")
      end
    end

    context "just past the boundary: the file sits under spec" do
      it "leaves the source rule out" do
        _exit_code, output, _error_output = run_library_lint_for_files({"spec/sample_spec.cr" => RAISE_SOURCE}, ["--all"])
        output.should_not contain("library/typed-raise")
      end

      it "leaves the source rule out when a spec path contains src" do
        _exit_code, output, _error_output = run_library_lint_for_files({"spec/src/sample_spec.cr" => RAISE_SOURCE}, ["--all"])
        output.should_not contain("library/typed-raise")
      end

      it "keeps carry-in-safe rules on a carried-in spec path" do
        rescue_source = %(def quiet_call\n  work\nrescue\n  nil\nend\n)
        _exit_code, output, _error_output = run_library_lint_for_files(
          {"spec/upstream/sample_spec.cr" => rescue_source},
          ["--all", "--carried-in", "spec/upstream"],
        )
        output.should contain("library/swallowed-rescue")
      end
    end
  end
end

describe AmberLSP::Rules::Library::Support::AnalyzeChangedMethodCollars do
  describe "#perform" do
    it "accepts a collar under the method's own type" do
      run_collar_check("Sample::Widget").should_not contain("library/changed-method-collar")
    end

    context "at the boundary: the describe names the type without its namespace" do
      it "accepts the short name" do
        run_collar_check("Widget").should_not contain("library/changed-method-collar")
      end

      it "accepts a string naming the type" do
        run_collar_check(%("Sample::Widget")).should_not contain("library/changed-method-collar")
      end

      it "accepts a string with a leading global scope" do
        run_collar_check(%("::Sample::Widget")).should_not contain("library/changed-method-collar")
      end

      it "keeps the enclosing type through a capitalized heading" do
        spec_source = "describe Sample::Widget do\n#{build_owner_spec(%("Behavior"))}\nend\n"
        run_collar_check_with_spec(spec_source).should_not contain("library/changed-method-collar")
      end

      it "accepts a describe with no type named" do
        run_collar_check(%("widget behavior")).should_not contain("library/changed-method-collar")
      end
    end

    context "just past the boundary: the collar belongs to another type" do
      it "reports the changed method" do
        run_collar_check("Other").should contain("library/changed-method-collar")
      end

      it "reports a longer namespace ending in the method's type" do
        run_collar_check("Other::Sample::Widget").should contain("library/changed-method-collar")
      end

      it "reports a wrong owner written with a leading global scope" do
        run_collar_check(%("::Other::Sample::Widget")).should contain("library/changed-method-collar")
      end

      it "reports a type sharing only a name suffix" do
        run_collar_check("SampleWidget").should contain("library/changed-method-collar")
      end
    end
  end
end

describe AmberLSP::Rules::Library::Support::GitChangedLines do
  describe "#perform" do
    it "selects an added line at the repository top level" do
      _exit_code, output, _error_output = run_changed_line_check("src/sample.cr")
      output.should contain("library/typed-raise")
    end

    context "at the boundary: paths git would otherwise rewrite" do
      it "selects a line when the root is below the git top level" do
        _exit_code, output, _error_output = run_changed_line_check("packages/core/src/sample.cr", "packages/core")
        output.should contain("library/typed-raise")
      end

      it "selects a line in a non-ASCII file name" do
        _exit_code, output, _error_output = run_changed_line_check("src/café.cr")
        output.should contain("library/typed-raise")
      end

      it "selects a line in a file name with a space" do
        _exit_code, output, _error_output = run_changed_line_check("src/two words.cr")
        output.should contain("library/typed-raise")
      end

      it "selects a line when git is configured without diff prefixes" do
        _exit_code, output, _error_output = run_changed_line_check("src/sample.cr", ".", [{"diff.noprefix", "true"}])
        output.should contain("library/typed-raise")
      end
    end

    context "just past the boundary: the change is outside the root" do
      it "reports nothing" do
        exit_code, output, _error_output = run_changed_line_check("packages/other/src/sample.cr", "packages/core")
        exit_code.should eq(0)
        output.should contain("0 issues")
      end
    end
  end
end

describe AmberLSP::LibraryLint::ReadLibraryLintExclusionPatterns do
  describe "#perform" do
    it "excludes a file matching a listed pattern" do
      _exit_code, output, _error_output = run_library_lint_for_files(
        {"src/generated/sample.cr" => RAISE_SOURCE},
        ["--all"],
        "exclude_patterns:\n  - src/generated/**\n",
      )
      output.should contain("0 issues")
    end

    context "at the boundary: an empty list" do
      it "excludes nothing" do
        _exit_code, output, _error_output = run_library_lint_for_files(
          {"src/sample.cr" => RAISE_SOURCE},
          ["--all"],
          "exclude_patterns: []\n",
        )
        output.should contain("library/typed-raise")
      end
    end

    context "just past the boundary: a value that is not a list of strings" do
      it "exits 2 for a scalar" do
        exit_code, _output, error_output = run_library_lint_for_files(
          {"src/sample.cr" => RAISE_SOURCE},
          ["--all"],
          "exclude_patterns: src/generated/**\n",
        )
        exit_code.should eq(2)
        error_output.should contain("exclude_patterns")
      end

      it "exits 2 for a list holding a number" do
        exit_code, _output, error_output = run_library_lint_for_files(
          {"src/sample.cr" => RAISE_SOURCE},
          ["--all"],
          "exclude_patterns:\n  - 7\n",
        )
        exit_code.should eq(2)
        error_output.should contain("exclude_patterns")
      end
    end
  end
end
