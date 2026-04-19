require "../../spec_helper"
require "../../../../src/amber_lsp/rules/mailers/required_methods_rule"

describe AmberLSP::Rules::Mailers::RequiredMethodsRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Mailers::RequiredMethodsRule.new)
  end

  describe "#check" do
    it "produces no diagnostics when both methods are defined" do
      content = <<-CRYSTAL
      class WelcomeMailer < Amber::Mailer::Base
        def html_body
          "<h1>Welcome</h1>"
        end

        def text_body
          "Welcome"
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Mailers::RequiredMethodsRule.new
      diagnostics = rule.check("src/mailers/welcome_mailer.cr", content)
      diagnostics.should be_empty
    end

    it "reports error when html_body is missing" do
      content = <<-CRYSTAL
      class WelcomeMailer < Amber::Mailer::Base
        def text_body
          "Welcome"
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Mailers::RequiredMethodsRule.new
      diagnostics = rule.check("src/mailers/welcome_mailer.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("amber/mailer-methods")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Error)
      diagnostics[0].message.should contain("html_body")
      diagnostics[0].message.should contain("WelcomeMailer")
    end

    it "reports error when text_body is missing" do
      content = <<-CRYSTAL
      class WelcomeMailer < Amber::Mailer::Base
        def html_body
          "<h1>Welcome</h1>"
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Mailers::RequiredMethodsRule.new
      diagnostics = rule.check("src/mailers/welcome_mailer.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("text_body")
    end

    it "reports two errors when both methods are missing" do
      content = <<-CRYSTAL
      class WelcomeMailer < Amber::Mailer::Base
        def deliver
          send_email
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Mailers::RequiredMethodsRule.new
      diagnostics = rule.check("src/mailers/welcome_mailer.cr", content)
      diagnostics.size.should eq(2)
      messages = diagnostics.map(&.message)
      messages.any? { |m| m.includes?("html_body") }.should be_true
      messages.any? { |m| m.includes?("text_body") }.should be_true
    end

    it "skips files not in mailers/ directory" do
      content = <<-CRYSTAL
      class WelcomeMailer < Amber::Mailer::Base
        def deliver
          send_email
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Mailers::RequiredMethodsRule.new
      diagnostics = rule.check("src/services/welcome_mailer.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for empty files" do
      rule = AmberLSP::Rules::Mailers::RequiredMethodsRule.new
      diagnostics = rule.check("src/mailers/welcome_mailer.cr", "")
      diagnostics.should be_empty
    end

    it "produces no diagnostics for files without mailer classes" do
      content = <<-CRYSTAL
      class Helper
        def html_body
          "not a mailer"
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Mailers::RequiredMethodsRule.new
      diagnostics = rule.check("src/mailers/helper.cr", content)
      diagnostics.should be_empty
    end

    it "handles mailer with methods that have arguments" do
      content = <<-CRYSTAL
      class WelcomeMailer < Amber::Mailer::Base
        def html_body(user : String)
          "<h1>Welcome</h1>"
        end

        def text_body(user : String)
          "Welcome"
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Mailers::RequiredMethodsRule.new
      diagnostics = rule.check("src/mailers/welcome_mailer.cr", content)
      diagnostics.should be_empty
    end
  end
end
