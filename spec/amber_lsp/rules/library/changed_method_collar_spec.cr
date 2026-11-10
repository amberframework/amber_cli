require "../../library_lint/spec_helper"

describe AmberLSP::Rules::Library::ChangedMethodCollar do
  describe "check-project behavior" do
    context "golden: a changed public method has all three collars" do
      it "passes" do
        source_before = "module Sample\n  class Widget\n    def process(value : Int32) : Int32\n      if value > 0\n        value\n      else\n        value\n      end\n      value + 1\n    end\n  end\nend"
        source_after = source_before.sub("value + 1", "value + 2")
        spec_source = <<-CRYSTAL
          describe "#process" do
            context "at the boundary: last accepted value" do
              it "accepts the value" do
                process(10).should eq(10)
              end
            end
            context "just past the boundary: first rejected value" do
              it "rejects the value" do
                expect_raises(ArgumentError) { raise ArgumentError.new("outside") }
              end
            end
            it "handles a typical value" do
              process(5).should eq(5)
            end
          end
          CRYSTAL
        base_files = {
          "src/widget.cr"       => source_before,
          "spec/widget_spec.cr" => spec_source,
        }
        changed_files = {"src/widget.cr" => source_after}
        exit_code, output, error_output = run_library_lint_with_git_changes(base_files, changed_files)

        exit_code.should eq(0)
        error_output.should be_empty
        output.should contain("0 issues (0 blocking, 0 advisory)")
      end
    end

    context "at the boundary: a changed method body line" do
      it "reports at the public def line when its describe has no collars" do
        source_before = "module Sample\n  class Widget\n    def process(value : Int32) : Int32\n      if value > 0\n        value\n      else\n        value\n      end\n      value + 1\n    end\n  end\nend"
        source_after = source_before.sub("value + 1", "value + 2")
        spec_source = "describe \"#process\" do\n  it \"handles a value\" do\n    process(5).should eq(5)\n  end\nend"
        base_files = {
          "src/widget.cr"       => source_before,
          "spec/widget_spec.cr" => spec_source,
        }
        changed_files = {"src/widget.cr" => source_after}
        exit_code, output, error_output = run_library_lint_with_git_changes(base_files, changed_files)

        exit_code.should eq(1)
        error_output.should be_empty
        output.should contain("src/widget.cr:3:")
        output.should contain("library/changed-method-collar")
        output.should contain("Method #process is missing:")
      end
    end
  end
end
