require "./spec_helper"

describe AmberLSP::Rules::Library::BuildLibraryRuleList do
  describe "#perform" do
    it "returns all 15 check-only library rules outside RuleRegistry" do
      registry_ids_before = AmberLSP::Rules::RuleRegistry.rules.map(&.id)
      list_of_rules = AmberLSP::Rules::Library::BuildLibraryRuleList.new(Dir.current).perform
      list_of_rule_ids = list_of_rules.map(&.id)

      list_of_rules.size.should eq(15)
      list_of_rule_ids.should eq(%w[
        library/typed-raise
        library/environment-read
        library/stdlib-reopen
        library/log-setup
        library/process-output
        library/swallowed-rescue
        library/unchecked-cast
        library/unsynchronized-class-variable
        library/disabled-certificate-verification
        library/public-return-type
        library/vague-internal-name
        library/collared-spec
        library/public-method-has-spec
        library/spec-without-assertion
        library/changed-method-collar
      ])
      list_of_rules.all? { |rule| !rule.requires_amber_project? }.should be_true
      AmberLSP::Rules::RuleRegistry.rules.map(&.id).should eq(registry_ids_before)
      AmberLSP::Rules::RuleRegistry.rules.any?(&.id.starts_with?("library/")).should be_false
    end
  end
end
