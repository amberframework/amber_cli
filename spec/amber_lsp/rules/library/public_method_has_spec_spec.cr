require "./spec_helper"

describe AmberLSP::Rules::Library::PublicMethodHasSpec do
  describe "#check" do
    context "golden: both method selector forms exist" do
      it "passes instance and class methods" do
        with_tempdir do |project_path|
          spec_directory = File.join(project_path, "spec")
          Dir.mkdir_p(spec_directory)
          File.write(
            File.join(spec_directory, "sample_spec.cr"),
            "describe \"#covered_instance_api\" do\nend\ndescribe \".covered_class_api\" do\nend",
          )
          rule = AmberLSP::Rules::Library::PublicMethodHasSpec.new(project_path)
          source_code = "def covered_instance_api(value : String) : String\n  value\nend\ndef covered_class_api(value : String) : String\n  value\nend"
          issues = library_rule_diagnostics(rule, source_code)
          issues.should be_empty
        end
      end
    end

    context "at the boundary: a public method has an argument" do
      it "reports the method without a selector" do
        with_tempdir do |project_path|
          rule = AmberLSP::Rules::Library::PublicMethodHasSpec.new(project_path)
          issues = library_rule_diagnostics(
            rule,
            "def uncovered_library_api(value : String) : String\n  value\nend",
          )
          issues.size.should eq(1)
          issues.first.message.should contain("uncovered_library_api")
        end
      end
    end

    context "just past the boundary: a method has no arguments" do
      it "passes" do
        with_tempdir do |project_path|
          rule = AmberLSP::Rules::Library::PublicMethodHasSpec.new(project_path)
          issues = library_rule_diagnostics(rule, "def no_arguments : Nil\nend")
          issues.should be_empty
        end
      end
    end

    context "when lifecycle, operator, private, and nodoc methods are defined" do
      it "passes those methods" do
        with_tempdir do |project_path|
          source_code = "class InternalAPI\n  def initialize(value : String)\n  end\n  def +(other : InternalAPI) : InternalAPI\n    self\n  end\n  private def private_lookup(value : String) : String\n    value\n  end\n  # :nodoc:\n  def internal_lookup(value : String) : String\n    value\n  end\nend"
          rule = AmberLSP::Rules::Library::PublicMethodHasSpec.new(project_path)
          issues = library_rule_diagnostics(rule, source_code)
          issues.should be_empty
        end
      end
    end
  end
end
