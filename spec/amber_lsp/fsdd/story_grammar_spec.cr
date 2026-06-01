require "../spec_helper"
require "../../../src/amber_lsp/rules/fsdd/story_grammar_rule"

describe AmberLSP::Rules::FSDD::StoryGrammarRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::FSDD::StoryGrammarRule.new)
  end

  describe "#check" do
    it "fires on a story block missing the action verb" do
      rule = AmberLSP::Rules::FSDD::StoryGrammarRule.new
      content = "# As a user\n# views the dashboard\n"
      diagnostics = rule.check("src/process_managers/users/create_user.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("fsdd/story-grammar")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Warning)
      diagnostics[0].message.should contain("missing action verb")
    end

    it "fires on a story block missing the model name" do
      rule = AmberLSP::Rules::FSDD::StoryGrammarRule.new
      content = "# As a user, I want to GET something from the list\n"
      diagnostics = rule.check("src/process_managers/users/create_user.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("missing capitalized Model name")
    end

    it "fires on a story block missing both verb and model" do
      rule = AmberLSP::Rules::FSDD::StoryGrammarRule.new
      content = "# As a user\n"
      diagnostics = rule.check("src/process_managers/users/create_user.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("missing action verb")
      diagnostics[0].message.should contain("missing capitalized Model name")
    end

    it "stays quiet on a complete persona story with GET verb and model" do
      rule = AmberLSP::Rules::FSDD::StoryGrammarRule.new
      content = "# As an Admin, I want to GET Users so I can manage the Account\n"
      diagnostics = rule.check("src/process_managers/users/create_user.cr", content)
      diagnostics.should be_empty
    end

    it "stays quiet on a complete persona story with POST verb" do
      rule = AmberLSP::Rules::FSDD::StoryGrammarRule.new
      content = "# As an Admin, I want to POST a new User to the system\n"
      diagnostics = rule.check("src/process_managers/users/create_user.cr", content)
      diagnostics.should be_empty
    end

    it "stays quiet on a complete scheduling story using perform verb" do
      rule = AmberLSP::Rules::FSDD::StoryGrammarRule.new
      content = "# At midnight on Monday, perform RetryPayments for all pending Orders\n"
      diagnostics = rule.check("src/process_managers/users/create_user.cr", content)
      diagnostics.should be_empty
    end

    it "stays quiet on a recurring story with do verb" do
      rule = AmberLSP::Rules::FSDD::StoryGrammarRule.new
      content = "# Every night, do LockExpiredAccounts for all Users\n"
      diagnostics = rule.check("src/process_managers/users/create_user.cr", content)
      diagnostics.should be_empty
    end

    it "stays quiet on a comment block with no story initiator" do
      rule = AmberLSP::Rules::FSDD::StoryGrammarRule.new
      content = "# Private helper that validates inputs\n# Returns nil if invalid\n"
      diagnostics = rule.check("src/process_managers/users/create_user.cr", content)
      diagnostics.should be_empty
    end

    it "stays quiet on regular code with no comments" do
      rule = AmberLSP::Rules::FSDD::StoryGrammarRule.new
      content = "def perform : Void\n  validate\nend\n"
      diagnostics = rule.check("src/process_managers/users/create_user.cr", content)
      diagnostics.should be_empty
    end

    it "flags only the incomplete story block in a mixed file" do
      rule = AmberLSP::Rules::FSDD::StoryGrammarRule.new
      content = <<-CRYSTAL
      # Regular comment about the class
      class Foo
        # As a user
        def perform : Void
        end
      end
      CRYSTAL
      diagnostics = rule.check("src/process_managers/users/create_user.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("missing action verb")
    end

    it "stays quiet on a complete multi-line story block" do
      rule = AmberLSP::Rules::FSDD::StoryGrammarRule.new
      content = <<-CRYSTAL
      # As an Admin, I want to DELETE a User
      # so that I can manage the Account membership
      # views the user management page after successful deletion
      def destroy : Void
      end
      CRYSTAL
      diagnostics = rule.check("src/process_managers/users/create_user.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for an empty file" do
      rule = AmberLSP::Rules::FSDD::StoryGrammarRule.new
      diagnostics = rule.check("src/process_managers/users/create_user.cr", "")
      diagnostics.should be_empty
    end
  end
end
