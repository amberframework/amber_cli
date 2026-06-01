require "../spec_helper"
require "../../../src/amber_lsp/rules/fsdd/doc_block_required_rule"

describe AmberLSP::Rules::FSDD::DocBlockRequiredRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::FSDD::DocBlockRequiredRule.new)
  end

  describe "#check" do
    it "flags a public def without a doc comment" do
      rule = AmberLSP::Rules::FSDD::DocBlockRequiredRule.new
      diagnostics = rule.check("src/models/user.cr", "def foo : String\nend\n")
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("fsdd/doc-block-required")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Information)
      diagnostics[0].message.should contain("foo")
    end

    it "flags a public class without a doc comment" do
      rule = AmberLSP::Rules::FSDD::DocBlockRequiredRule.new
      diagnostics = rule.check("src/models/user.cr", "class User\nend\n")
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("User")
    end

    it "stays quiet when a doc comment immediately precedes a public def" do
      rule = AmberLSP::Rules::FSDD::DocBlockRequiredRule.new
      content = "# Returns a greeting\ndef foo : String\nend\n"
      diagnostics = rule.check("src/models/user.cr", content)
      diagnostics.should be_empty
    end

    it "stays quiet when a doc comment immediately precedes a public class" do
      rule = AmberLSP::Rules::FSDD::DocBlockRequiredRule.new
      content = "# User model\nclass User\nend\n"
      diagnostics = rule.check("src/models/user.cr", content)
      diagnostics.should be_empty
    end

    it "stays quiet on private def" do
      rule = AmberLSP::Rules::FSDD::DocBlockRequiredRule.new
      diagnostics = rule.check("src/models/user.cr", "private def foo : String\nend\n")
      diagnostics.should be_empty
    end

    it "stays quiet on protected def" do
      rule = AmberLSP::Rules::FSDD::DocBlockRequiredRule.new
      diagnostics = rule.check("src/models/user.cr", "protected def foo : String\nend\n")
      diagnostics.should be_empty
    end

    it "stays quiet on a def preceded by a standalone private keyword" do
      rule = AmberLSP::Rules::FSDD::DocBlockRequiredRule.new
      content = "private\n\ndef foo : String\nend\n"
      diagnostics = rule.check("src/models/user.cr", content)
      diagnostics.should be_empty
    end

    it "flags multiple undocumented public methods in one file" do
      rule = AmberLSP::Rules::FSDD::DocBlockRequiredRule.new
      content = <<-CRYSTAL
      def foo : String
        "foo"
      end

      def bar : Int32
        42
      end
      CRYSTAL
      diagnostics = rule.check("src/models/user.cr", content)
      diagnostics.size.should eq(2)
    end

    it "flags only the undocumented method when another method has a doc comment" do
      rule = AmberLSP::Rules::FSDD::DocBlockRequiredRule.new
      content = <<-CRYSTAL
      # Documented
      def good : String
        "ok"
      end

      def bad : Int32
        42
      end
      CRYSTAL
      diagnostics = rule.check("src/models/user.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("bad")
    end

    it "stays quiet on an abstract class preceded by a doc comment" do
      rule = AmberLSP::Rules::FSDD::DocBlockRequiredRule.new
      content = "# Base rule\nabstract class BaseRule\nend\n"
      diagnostics = rule.check("src/models/user.cr", content)
      diagnostics.should be_empty
    end

    it "flags an abstract def without a doc comment" do
      rule = AmberLSP::Rules::FSDD::DocBlockRequiredRule.new
      diagnostics = rule.check("src/models/user.cr", "abstract def perform : Void\n")
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("perform")
    end

    it "produces no diagnostics for an empty file" do
      rule = AmberLSP::Rules::FSDD::DocBlockRequiredRule.new
      diagnostics = rule.check("src/models/user.cr", "")
      diagnostics.should be_empty
    end
  end
end
