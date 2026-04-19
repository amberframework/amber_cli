require "./spec_helper"

# Reuse MockTestRule and MockControllerRule from analyzer_spec
# But we need to define them here too since specs can run independently

class RegistryMockRule < AmberLSP::Rules::BaseRule
  def id : String
    "registry/mock-rule"
  end

  def description : String
    "A mock rule for registry testing"
  end

  def default_severity : AmberLSP::Rules::Severity
    AmberLSP::Rules::Severity::Warning
  end

  def applies_to : Array(String)
    ["*.cr"]
  end

  def check(file_path : String, content : String) : Array(AmberLSP::Rules::Diagnostic)
    [] of AmberLSP::Rules::Diagnostic
  end
end

class RegistryControllerMockRule < AmberLSP::Rules::BaseRule
  def id : String
    "registry/controller-mock"
  end

  def description : String
    "A controller-only rule"
  end

  def default_severity : AmberLSP::Rules::Severity
    AmberLSP::Rules::Severity::Error
  end

  def applies_to : Array(String)
    ["*_controller.cr"]
  end

  def check(file_path : String, content : String) : Array(AmberLSP::Rules::Diagnostic)
    [] of AmberLSP::Rules::Diagnostic
  end
end

describe AmberLSP::Rules::RuleRegistry do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
  end

  describe ".register and .rules" do
    it "registers and returns rules" do
      rule = RegistryMockRule.new
      AmberLSP::Rules::RuleRegistry.register(rule)

      AmberLSP::Rules::RuleRegistry.rules.size.should eq(1)
      AmberLSP::Rules::RuleRegistry.rules[0].id.should eq("registry/mock-rule")
    end

    it "accumulates multiple rules" do
      AmberLSP::Rules::RuleRegistry.register(RegistryMockRule.new)
      AmberLSP::Rules::RuleRegistry.register(RegistryControllerMockRule.new)

      AmberLSP::Rules::RuleRegistry.rules.size.should eq(2)
    end
  end

  describe ".rules_for_file" do
    it "returns rules that match the file path" do
      AmberLSP::Rules::RuleRegistry.register(RegistryMockRule.new)
      AmberLSP::Rules::RuleRegistry.register(RegistryControllerMockRule.new)

      # *.cr matches any .cr file
      rules = AmberLSP::Rules::RuleRegistry.rules_for_file("src/models/user.cr")
      rules.size.should eq(1)
      rules[0].id.should eq("registry/mock-rule")
    end

    it "returns controller rules for controller files" do
      AmberLSP::Rules::RuleRegistry.register(RegistryMockRule.new)
      AmberLSP::Rules::RuleRegistry.register(RegistryControllerMockRule.new)

      rules = AmberLSP::Rules::RuleRegistry.rules_for_file("src/controllers/home_controller.cr")
      rules.size.should eq(2)
    end

    it "returns empty array when no rules match" do
      AmberLSP::Rules::RuleRegistry.register(RegistryControllerMockRule.new)

      rules = AmberLSP::Rules::RuleRegistry.rules_for_file("src/models/user.cr")
      rules.should be_empty
    end
  end

  describe ".clear" do
    it "removes all registered rules" do
      AmberLSP::Rules::RuleRegistry.register(RegistryMockRule.new)
      AmberLSP::Rules::RuleRegistry.clear

      AmberLSP::Rules::RuleRegistry.rules.should be_empty
    end
  end
end
