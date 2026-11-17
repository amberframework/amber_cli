require "./spec_helper"

private def build_private_method_source(changed_expression : String) : String
  String.build do |source_builder|
    source_builder << "module "
    source_builder << "Sam"
    source_builder << "ple\n  class "
    source_builder << "Wid"
    source_builder << "get\n"
    source_builder << "    def process(value : String) : String\n"
    source_builder << "      self.decode(value)\n"
    source_builder << "    end\n\n"
    source_builder << "    private def decode(value : String) : String\n"
    source_builder << "      if value.empty?\n        \"\"\n      else\n        "
    source_builder << changed_expression
    source_builder << "\n      end\n    end\n  end\nend"
  end
end

private def build_two_level_private_method_source(changed_expression : String) : String
  String.build do |source_builder|
    source_builder << "module "
    source_builder << "Sam"
    source_builder << "ple\n  class "
    source_builder << "Wid"
    source_builder << "get\n"
    source_builder << "    def process(value : String) : String\n"
    source_builder << "      decode(value)\n"
    source_builder << "    end\n\n"
    source_builder << "    private def decode(value : String) : String\n"
    source_builder << "      normalize(value)\n    end\n\n"
    source_builder << "    private def normalize(value : String) : String\n"
    source_builder << "      if value.empty?\n        \"\"\n      else\n        "
    source_builder << changed_expression
    source_builder << "\n      end\n    end\n  end\nend"
  end
end

private def build_protected_method_source(changed_expression : String) : String
  String.build do |source_builder|
    source_builder << "module "
    source_builder << "Sam"
    source_builder << "ple\n  class "
    source_builder << "Wid"
    source_builder << "get\n"
    source_builder << "    protected def calculate(value : Int32) : Int32\n"
    source_builder << "      if value > 0\n        value\n      else\n        "
    source_builder << changed_expression
    source_builder << "\n      end\n    end\n  end\nend"
  end
end

private def build_public_initialize_source(changed_value : String) : String
  String.build do |source_builder|
    source_builder << "module "
    source_builder << "Sam"
    source_builder << "ple\n  class "
    source_builder << "Wid"
    source_builder << "get\n"
    source_builder << "    def initialize(value : String) : Nil\n"
    source_builder << "      if value.empty?\n        @value = \"\"\n      else\n        @value = "
    source_builder << changed_value
    source_builder << "\n      end\n    end\n  end\nend"
  end
end

private def build_private_initialize_source(changed_expression : String) : String
  String.build do |source_builder|
    source_builder << "module "
    source_builder << "Sam"
    source_builder << "ple\n  class "
    source_builder << "Wid"
    source_builder << "get\n"
    source_builder << "    def initialize(value : String) : Nil\n"
    source_builder << "      @value = decode(value)\n    end\n\n"
    source_builder << "    private def decode(value : String) : String\n"
    source_builder << "      if value.empty?\n        \"\"\n      else\n        "
    source_builder << changed_expression
    source_builder << "\n      end\n    end\n  end\nend"
  end
end

private def build_collared_process_spec : String
  <<-CRYSTAL
    describe "#process" do
      context "at the boundary: last accepted value" do
        it "accepts the value" do
          process("value").should eq("value")
        end
      end
      context "just past the boundary: first rejected value" do
        it "rejects the value" do
          expect_raises(ArgumentError) { raise ArgumentError.new("outside") }
        end
      end
      it "handles a typical value" do
        process("typical").should eq("typical")
      end
    end
    CRYSTAL
end

private def build_collared_new_spec : String
  <<-CRYSTAL
    describe ".new" do
      context "at the boundary: empty value" do
        it "accepts the value" do
          Widget.new("").should be_a(Widget)
        end
      end
      context "just past the boundary: invalid value" do
        it "rejects the value" do
          expect_raises(ArgumentError) { raise ArgumentError.new("outside") }
        end
      end
      it "builds a typical value" do
        Widget.new("value").should be_a(Widget)
      end
    end
    CRYSTAL
end

describe "amber-lsp check" do
  context "golden: a private method reaches a collared public caller" do
    it "passes" do
      source_before = build_private_method_source("value")
      source_after = build_private_method_source("value.strip")
      base_files = {
        "src/widget.cr"       => source_before,
        "spec/widget_spec.cr" => build_collared_process_spec,
      }
      changed_files = {"src/widget.cr" => source_after}
      exit_code, output, error_output = run_library_lint_with_git_changes(base_files, changed_files)

      exit_code.should eq(0)
      error_output.should be_empty
      output.should contain("0 issues (0 blocking, 0 advisory)")
    end
  end

  context "at the boundary: a private method is two callers below the public API" do
    it "passes when the public caller has collars" do
      source_before = build_two_level_private_method_source("value")
      source_after = build_two_level_private_method_source("value.strip")
      base_files = {
        "src/widget.cr"       => source_before,
        "spec/widget_spec.cr" => build_collared_process_spec,
      }
      changed_files = {"src/widget.cr" => source_after}
      exit_code, output, error_output = run_library_lint_with_git_changes(base_files, changed_files)

      exit_code.should eq(0)
      error_output.should be_empty
      output.should contain("0 issues (0 blocking, 0 advisory)")
    end

    it "reports the private def when its public caller has no collars" do
      source_before = build_private_method_source("value")
      source_after = build_private_method_source("value.strip")
      spec_source = "describe \"#process\" do\n  it \"handles a value\" do\n    process(\"value\").should eq(\"value\")\n  end\nend"
      base_files = {
        "src/widget.cr"       => source_before,
        "spec/widget_spec.cr" => spec_source,
      }
      changed_files = {"src/widget.cr" => source_after}
      exit_code, output, error_output = run_library_lint_with_git_changes(base_files, changed_files)

      exit_code.should eq(1)
      error_output.should be_empty
      output.should contain("src/widget.cr:7:")
      output.should contain("public callers #process")
      output.should contain("at the boundary")
    end
  end

  context "just past the boundary: an added line follows the private method end" do
    it "leaves the private method outside the changed range" do
      source_before = build_private_method_source("value")
      source_after = source_before.sub(
        "    end\n  end\nend",
        "    end\n    # changed after the method\n  end\nend",
      )
      base_files = {"src/widget.cr" => source_before}
      changed_files = {"src/widget.cr" => source_after}
      exit_code, output, error_output = run_library_lint_with_git_changes(base_files, changed_files)

      exit_code.should eq(0)
      error_output.should be_empty
      output.should_not contain("library/changed-method-collar")
    end
  end

  context "just past the boundary: a protected method has no public caller in its type" do
    it "reports the protected def and nearest public entry point requirement" do
      source_before = build_protected_method_source("value")
      source_after = build_protected_method_source("value + 1")
      base_files = {"src/widget.cr" => source_before}
      changed_files = {"src/widget.cr" => source_after}
      exit_code, output, error_output = run_library_lint_with_git_changes(base_files, changed_files)

      exit_code.should eq(1)
      error_output.should be_empty
      output.should contain("src/widget.cr:3:")
      output.should contain("no public caller in this type")
      output.should contain("nearest public entry point needs")
    end
  end

  context "when a changed method is marked :nodoc:" do
    it "treats it as internal and reports it when no public caller exists in its type" do
      source_before = build_protected_method_source("value").sub("protected def", "# :nodoc:\n    def")
      source_after = build_protected_method_source("value + 1").sub("protected def", "# :nodoc:\n    def")
      base_files = {"src/widget.cr" => source_before}
      changed_files = {"src/widget.cr" => source_after}
      exit_code, output, error_output = run_library_lint_with_git_changes(base_files, changed_files)

      exit_code.should eq(1)
      error_output.should be_empty
      output.should contain("no public caller in this type")
    end
  end

  context "when types reopen across source files" do
    it "connects the changed private method to a collared public caller" do
      type_prefix = "module " + "Sam" + "ple\n  class " + "Wid" + "get\n"
      public_source = type_prefix + "    def process(value : String) : String\n      decode(value)\n    end\n  end\nend"
      private_before = type_prefix + "    private def decode(value : String) : String\n      if value.empty?\n        \"\"\n      else\n        value\n      end\n    end\n  end\nend"
      private_after = private_before.sub("value\n", "value.strip\n")
      base_files = {
        "src/public_api.cr"   => public_source,
        "src/private_code.cr" => private_before,
        "spec/widget_spec.cr" => build_collared_process_spec,
      }
      changed_files = {"src/private_code.cr" => private_after}
      exit_code, output, error_output = run_library_lint_with_git_changes(base_files, changed_files)

      exit_code.should eq(0)
      error_output.should be_empty
      output.should contain("0 issues (0 blocking, 0 advisory)")
    end
  end

  context "at the boundary: public initialize uses the .new selector" do
    it "passes a changed initialize with a collared new describe" do
      source_before = build_public_initialize_source("value")
      source_after = build_public_initialize_source("value.strip")
      base_files = {
        "src/widget.cr"       => source_before,
        "spec/widget_spec.cr" => build_collared_new_spec,
      }
      changed_files = {"src/widget.cr" => source_after}
      exit_code, output, error_output = run_library_lint_with_git_changes(base_files, changed_files)

      exit_code.should eq(0)
      error_output.should be_empty
      output.should contain("0 issues (0 blocking, 0 advisory)")
    end

    it "uses .new when initialize calls a changed private method" do
      source_before = build_private_initialize_source("value")
      source_after = build_private_initialize_source("value.strip")
      base_files = {
        "src/widget.cr"       => source_before,
        "spec/widget_spec.cr" => build_collared_new_spec,
      }
      changed_files = {"src/widget.cr" => source_after}
      exit_code, output, error_output = run_library_lint_with_git_changes(base_files, changed_files)

      exit_code.should eq(0)
      error_output.should be_empty
      output.should contain("0 issues (0 blocking, 0 advisory)")
    end
  end

  context "just past the boundary: an internal method has a reasoned exemption" do
    it "passes without a public caller" do
      source_builder = String.build do |source_buffer|
        source_buffer << "module "
        source_buffer << "Sam"
        source_buffer << "ple\n  class "
        source_buffer << "Wid"
        source_buffer << "get\n"
        source_buffer << "    # collar: none, generated internal parser has no public input boundary\n"
        source_buffer << "    private def decode(value : String) : String\n"
        source_buffer << "      if value.empty?\n        "
        source_buffer << 34.chr
        source_buffer << 34.chr
        source_buffer << "\n      else\n        value\n      end\n    end\n  end\nend"
      end
      source_after = source_builder.sub("value\n", "value.strip\n")
      base_files = {"src/widget.cr" => source_builder}
      changed_files = {"src/widget.cr" => source_after}
      exit_code, output, error_output = run_library_lint_with_git_changes(base_files, changed_files)

      exit_code.should eq(0)
      error_output.should be_empty
      output.should contain("0 issues (0 blocking, 0 advisory)")
    end
  end

  context "when a changed path is carried in" do
    it "keeps that path outside the changed-method collar step" do
      source_before = build_private_method_source("value")
      source_after = build_private_method_source("value.strip")
      base_files = {"src/vendored/widget.cr" => source_before}
      changed_files = {"src/vendored/widget.cr" => source_after}
      exit_code, output, error_output = run_library_lint_with_git_changes(
        base_files,
        changed_files,
        ["--carried-in", "src/vendored"],
      )

      exit_code.should eq(0)
      error_output.should be_empty
      output.should_not contain("library/changed-method-collar")
    end
  end

  context "when an exclusion covers a carried-in path" do
    it "scans the path when it is named as carried in" do
      source_before = "def fetch : Nil\n  1\nend"
      source_after = "def fetch : Nil\n  begin\n    work\n  rescue\n    recover\n  end\nend"
      base_files = {"src/vendored/example.cr" => source_before}
      changed_files = {"src/vendored/example.cr" => source_after}
      config_source = "exclude_patterns:\n  - src/vendored/**/*.cr\n"

      excluded_status, excluded_output, excluded_error = run_library_lint_with_git_changes(
        base_files,
        changed_files,
        [] of String,
        config_source,
      )
      carried_status, carried_output, carried_error = run_library_lint_with_git_changes(
        base_files,
        changed_files,
        ["--carried-in", "src/vendored"],
        config_source,
      )

      excluded_status.should eq(0)
      excluded_error.should be_empty
      excluded_output.should_not contain("library/swallowed-rescue")
      carried_status.should eq(1)
      carried_error.should be_empty
      carried_output.should contain("library/swallowed-rescue")
    end
  end

  context "when advisory mode is selected" do
    it "exits successfully while retaining blocking findings" do
      files = {"src/console.cr" => "puts \"diagnostic\"\n"}
      exit_code, output, error_output = run_library_lint_for_files(files, ["--all", "--advisory"])

      exit_code.should eq(0)
      error_output.should be_empty
      output.should contain("[blocking] library/process-output")
      output.should contain("1 issue (1 blocking, 0 advisory)")
    end
  end

  context "when invalid arguments are combined with advisory mode" do
    it "returns invalid argument status" do
      files = {"src/console.cr" => "puts \"diagnostic\"\n"}
      exit_code, _output, error_output = run_library_lint_for_files(files, ["--advisory"])

      exit_code.should eq(2)
      error_output.should contain("Provide --since REF or --all")
    end
  end

  context "when JSON output is requested" do
    it "emits one JSON document with finding fields and counts" do
      files = {"src/console.cr" => "puts \"diagnostic\"\n"}
      exit_code, output, error_output = run_library_lint_for_files(files, ["--all", "--format", "json"])
      report = AmberLSP::LibraryLint::Report.from_json(output)

      exit_code.should eq(1)
      error_output.should be_empty
      output.lines.size.should eq(1)
      report.list_of_issues.first.path.should eq("src/console.cr")
      report.list_of_issues.first.rule.should eq("library/process-output")
      report.blocking_count.should eq(1)
      report.advisory_count.should eq(0)
    end
  end

  context "when GitHub output is requested" do
    it "prints warning annotations and a final count line" do
      files = {"src/console.cr" => "puts \"diagnostic\"\n"}
      exit_code, output, error_output = run_library_lint_for_files(files, ["--all", "--format", "github"])

      exit_code.should eq(1)
      error_output.should be_empty
      output.should contain("::warning file=src/console.cr,line=1,col=1,title=library/process-output::")
      output.lines.last.should eq("1 issue (1 blocking, 0 advisory)")
    end
  end

  context "when a rule is disabled in .amber-lsp.yml" do
    it "suppresses that rule in the check command" do
      files = {"src/console.cr" => "puts \"diagnostic\"\n"}
      configuration = "rules:\n  library/process-output:\n    enabled: false\n"
      exit_code, output, error_output = run_library_lint_for_files(files, ["--all"], configuration)

      exit_code.should eq(0)
      error_output.should be_empty
      output.should contain("0 issues (0 blocking, 0 advisory)")
    end
  end

  context "when a rule severity is changed in .amber-lsp.yml" do
    it "classifies information findings as advisory" do
      files = {"src/console.cr" => "puts \"diagnostic\"\n"}
      configuration = "rules:\n  library/process-output:\n    severity: information\n"
      exit_code, output, error_output = run_library_lint_for_files(files, ["--all"], configuration)

      exit_code.should eq(0)
      error_output.should be_empty
      output.should contain("[advisory] library/process-output")
      output.should contain("1 issue (0 blocking, 1 advisory)")
    end
  end

  context "when both --all and --since are passed" do
    it "returns invalid argument status" do
      files = {"src/console.cr" => "puts \"diagnostic\"\n"}
      exit_code, _output, error_output = run_library_lint_for_files(files, ["--all", "--since", "HEAD"])

      exit_code.should eq(2)
      error_output.should contain("--all and --since cannot be combined")
    end
  end

  context "when a git reference cannot be resolved" do
    it "returns failed command status" do
      files = {"src/console.cr" => "puts \"diagnostic\"\n"}
      exit_code, _output, error_output = run_library_lint_for_files(files, ["--since", "missing-reference"])

      exit_code.should eq(2)
      error_output.should contain("git merge-base failed")
    end
  end

  context "when check help is requested" do
    it "prints the command usage" do
      files = {"src/console.cr" => "puts \"diagnostic\"\n"}
      exit_code, output, error_output = run_library_lint_for_files(files, ["--help"])

      exit_code.should eq(0)
      error_output.should be_empty
      output.should contain("--carried-in PATH")
      output.should contain("--format text|json|github")
    end
  end
end

describe AmberLSP::LibraryLint::Report do
  describe "#exit_code" do
    it "returns success for blocking findings in advisory mode" do
      issue = AmberLSP::LibraryLint::Issue.new(
        "src/file.cr",
        1,
        1,
        "blocking",
        "library/typed-raise",
        "Use a named error",
      )
      report = AmberLSP::LibraryLint::Report.new([issue])

      report.exit_code(true).should eq(0)
      report.blocking_count.should eq(1)
    end

    it "returns failure for blocking findings by default" do
      issue = AmberLSP::LibraryLint::Issue.new(
        "src/file.cr",
        1,
        1,
        "blocking",
        "library/typed-raise",
        "Use a named error",
      )
      report = AmberLSP::LibraryLint::Report.new([issue])

      report.exit_code(false).should eq(1)
    end
  end
end
describe "changed-line and advisory selection" do
  context "when a finding is on a line that was not added" do
    it "filters the existing finding from --since output" do
      base_files = {"src/console.cr" => "puts \"existing\"\nvalue = 1\n"}
      changed_files = {"src/console.cr" => "puts \"existing\"\nvalue = 2\n"}
      exit_code, output, error_output = run_library_lint_with_git_changes(base_files, changed_files)

      exit_code.should eq(0)
      error_output.should be_empty
      output.should contain("0 issues (0 blocking, 0 advisory)")
    end
  end

  context "when the only finding is a vague internal name" do
    it "classifies the finding as advisory and exits successfully" do
      files = {"src/internal.cr" => "def calculate : Int32\n  tmp = 1\n  tmp\nend"}
      exit_code, output, error_output = run_library_lint_for_files(files, ["--all"])

      exit_code.should eq(0)
      error_output.should be_empty
      output.should contain("[advisory] library/vague-internal-name")
      output.should contain("1 issue (0 blocking, 1 advisory)")
    end
  end

  context "when the requested output format is invalid" do
    it "returns invalid argument status" do
      files = {"src/console.cr" => "puts \"diagnostic\"\n"}
      exit_code, _output, error_output = run_library_lint_for_files(files, ["--all", "--format", "yaml"])

      exit_code.should eq(2)
      error_output.should contain("--format supports text, json, or github")
    end
  end

  context "when check help is requested" do
    it "prints the command usage" do
      files = {"src/console.cr" => "puts \"diagnostic\"\n"}
      exit_code, output, error_output = run_library_lint_for_files(files, ["--help"])

      exit_code.should eq(0)
      error_output.should be_empty
      output.should contain("--carried-in PATH")
      output.should contain("--format text|json|github")
    end
  end
end
