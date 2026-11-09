require "./spec_helper"

describe AmberLSP::Rules::Library::VagueInternalName do
  describe "#check" do
    context "when a local uses a vague name" do
      it "reports the local declaration" do
        source_code = "def calculate : Int32\n  tmp = 1\n  tmp\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::VagueInternalName.new, source_code)
        issues.size.should eq(1)
      end
    end

    context "when a block parameter uses a vague name" do
      it "reports the block parameter" do
        block_parameter_name = 120.chr
        source_code = "[1].each do |#{block_parameter_name}|\n  #{block_parameter_name}\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::VagueInternalName.new, source_code)
        issues.size.should eq(1)
      end
    end

    context "when a private method parameter uses a vague name" do
      it "reports the parameter" do
        issues = library_rule_diagnostics(
          AmberLSP::Rules::Library::VagueInternalName.new,
          "private def parse(val : String)\n  val\nend",
        )
        issues.size.should eq(1)
      end
    end

    context "when a name is underscored or a loop index" do
      it "passes" do
        source_code = "def calculate : Int32\n  _tmp = 1\n  i = 2\n  j = 3\n  k = 4\n  i\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::VagueInternalName.new, source_code)
        issues.should be_empty
      end
    end

    context "when a public method parameter uses a short name" do
      it "passes the parameter" do
        issues = library_rule_diagnostics(
          AmberLSP::Rules::Library::VagueInternalName.new,
          "def parse(tmp : String) : String\n  tmp\nend",
        )
        issues.should be_empty
      end
    end
  end
end
describe "top-level local names" do
  it "reports a vague variable assigned outside a method" do
    issues = library_rule_diagnostics(
      AmberLSP::Rules::Library::VagueInternalName.new,
      "tmp = 1",
    )
    issues.size.should eq(1)
  end
end
