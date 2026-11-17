require "./spec_helper"

describe AmberLSP::Rules::Library::LogSetup do
  describe "#check" do
    context "when global Log setup is called" do
      it "reports setup" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::LogSetup.new, "Log.setup do\nend")
        issues.size.should eq(1)
      end

      it "reports setup_from_env" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::LogSetup.new, "Log.setup_from_env")
        issues.size.should eq(1)
      end

      it "reports the global Log path" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::LogSetup.new, "::Log.setup")
        issues.size.should eq(1)
      end
    end

    context "when a library logger is created" do
      it "passes" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::LogSetup.new, "Log.for(self)")
        issues.should be_empty
      end
    end
  end
end
