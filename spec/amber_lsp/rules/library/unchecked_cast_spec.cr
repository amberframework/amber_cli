require "./spec_helper"

describe AmberLSP::Rules::Library::UncheckedCast do
  describe "#check" do
    context "when a value is cast to a named type" do
      it "reports the unchecked cast" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::UncheckedCast.new, "value.as(Int32)")
        issues.size.should eq(1)
      end

      it "reports a generic named type cast" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::UncheckedCast.new, "value.as(Array(String))")
        issues.size.should eq(1)
      end
    end

    context "when a pointer type is used" do
      it "passes" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::UncheckedCast.new, "value.as(Void*)")
        issues.should be_empty
      end
    end

    context "when nil or a checked cast is used" do
      it "passes" do
        nil_issues = library_rule_diagnostics(AmberLSP::Rules::Library::UncheckedCast.new, "nil.as(String)")
        checked_issues = library_rule_diagnostics(AmberLSP::Rules::Library::UncheckedCast.new, "value.as?(String)")
        nil_issues.should be_empty
        checked_issues.should be_empty
      end
    end
  end
end
