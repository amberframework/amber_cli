require "./spec_helper"

describe AmberLSP::Rules::Library::EnvironmentRead do
  describe "#check" do
    context "when a call uses ENV" do
      it "reports a receiver call" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::EnvironmentRead.new, "ENV[\"TOKEN\"]")
        issues.size.should eq(1)
      end

      it "reports the global ENV path" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::EnvironmentRead.new, "::ENV[\"TOKEN\"]")
        issues.size.should eq(1)
      end
    end

    context "when another path is used" do
      it "passes" do
        issues = library_rule_diagnostics(AmberLSP::Rules::Library::EnvironmentRead.new, "Application::ENV[\"TOKEN\"]")
        issues.should be_empty
      end
    end
  end
end
