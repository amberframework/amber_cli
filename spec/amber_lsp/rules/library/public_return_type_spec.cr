require "./spec_helper"

describe AmberLSP::Rules::Library::PublicReturnType do
  describe "#check" do
    context "when a public method has no return type" do
      it "reports the method" do
        source_code = "class API\n  def read\n    1\n  end\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::PublicReturnType.new, source_code)
        issues.size.should eq(1)
      end
    end

    context "when a special method has no return type" do
      it "passes initialize and finalize" do
        source_code = "class API\n  def initialize\n  end\n  def finalize\n  end\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::PublicReturnType.new, source_code)
        issues.should be_empty
      end
    end

    context "when a method is private or protected" do
      it "passes" do
        source_code = "class API\n  private def read\n  end\n  protected def write\n  end\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::PublicReturnType.new, source_code)
        issues.should be_empty
      end
    end

    context "when a definition is under a nodoc comment" do
      it "passes" do
        source_code = "# :nodoc:\nmodule InternalAPI\n  def read\n  end\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::PublicReturnType.new, source_code)
        issues.should be_empty
      end
    end

    context "when a public method has an explicit return type" do
      it "passes" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::PublicReturnType.new, "def read : Int32\n  1\nend")
        issues.should be_empty
      end
    end
  end
end
