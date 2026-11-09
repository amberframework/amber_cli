require "./spec_helper"

describe AmberLSP::Rules::Library::SwallowedRescue do
  describe "#check" do
    context "golden: broad rescues preserve or re-raise the cause" do
      it "passes a replacement error with cause:" do
        source_code = "begin\n  work\nrescue ex : Exception\n  raise Error.new(ex.message, cause: ex)\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::SwallowedRescue.new, source_code)
        issues.should be_empty
      end

      it "passes a bare re-raise" do
        source_code = "begin\n  work\nrescue\n  raise\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::SwallowedRescue.new, source_code)
        issues.should be_empty
      end

      it "passes when re-raising the rescued value" do
        source_code = "begin\n  work\nrescue ex\n  raise ex\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::SwallowedRescue.new, source_code)
        issues.should be_empty
      end
    end

    context "at the boundary: a broad rescue replaces an error" do
      it "reports a replacement without cause:" do
        source_code = "begin\n  work\nrescue ex : Exception\n  raise Error.new(ex.message)\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::SwallowedRescue.new, source_code)
        issues.map(&.message).should eq(["Pass cause: when converting a broad rescue into a new error"])
      end
    end

    context "just past the boundary: a specific rescue converts an error" do
      it "allows a typed rescue conversion" do
        source_code = "begin\n  work\nrescue ex : ArgumentError\n  raise Error.new(ex.message)\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::SwallowedRescue.new, source_code)
        issues.should be_empty
      end
    end

    context "when a broad rescue does not raise" do
      it "reports the swallowed rescue" do
        source_code = "begin\n  work\nrescue\n  recover\nend"
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::SwallowedRescue.new, source_code)
        issues.size.should eq(1)
        issues.first.message.should eq("Reraise or rescue a specific error")
      end
    end
  end
end
