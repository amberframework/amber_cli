require "../../spec_helper"
require "../../../../src/amber_lsp/rules/file_naming/snake_case_rule"

describe AmberLSP::Rules::FileNaming::SnakeCaseRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::FileNaming::SnakeCaseRule.new)
  end

  describe "#check" do
    it "produces no diagnostics for snake_case file names" do
      rule = AmberLSP::Rules::FileNaming::SnakeCaseRule.new
      diagnostics = rule.check("src/controllers/posts_controller.cr", "")
      diagnostics.should be_empty
    end

    it "produces no diagnostics for single word file names" do
      rule = AmberLSP::Rules::FileNaming::SnakeCaseRule.new
      diagnostics = rule.check("src/models/user.cr", "")
      diagnostics.should be_empty
    end

    it "reports warning for PascalCase file names" do
      rule = AmberLSP::Rules::FileNaming::SnakeCaseRule.new
      diagnostics = rule.check("src/controllers/PostsController.cr", "")
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("amber/file-naming")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Warning)
      diagnostics[0].message.should contain("PostsController.cr")
      diagnostics[0].message.should contain("posts_controller.cr")
    end

    it "reports warning for camelCase file names" do
      rule = AmberLSP::Rules::FileNaming::SnakeCaseRule.new
      diagnostics = rule.check("src/models/userProfile.cr", "")
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("userProfile.cr")
      diagnostics[0].message.should contain("user_profile.cr")
    end

    it "reports warning for hyphenated file names" do
      rule = AmberLSP::Rules::FileNaming::SnakeCaseRule.new
      diagnostics = rule.check("src/models/user-profile.cr", "")
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("user-profile.cr")
    end

    it "reports warning for file names starting with uppercase" do
      rule = AmberLSP::Rules::FileNaming::SnakeCaseRule.new
      diagnostics = rule.check("src/models/User.cr", "")
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("User.cr")
      diagnostics[0].message.should contain("user.cr")
    end

    it "skips hidden files" do
      rule = AmberLSP::Rules::FileNaming::SnakeCaseRule.new
      diagnostics = rule.check("src/.hidden_file.cr", "")
      diagnostics.should be_empty
    end

    it "allows file names with numbers" do
      rule = AmberLSP::Rules::FileNaming::SnakeCaseRule.new
      diagnostics = rule.check("src/models/v2_user.cr", "")
      diagnostics.should be_empty
    end

    it "positions diagnostic at line 0, col 0" do
      rule = AmberLSP::Rules::FileNaming::SnakeCaseRule.new
      diagnostics = rule.check("src/BadName.cr", "")
      diagnostics.size.should eq(1)
      diagnostics[0].range.start.line.should eq(0)
      diagnostics[0].range.start.character.should eq(0)
    end
  end
end
