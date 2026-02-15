require "../../spec_helper"
require "../../../../src/amber_lsp/rules/jobs/perform_rule"

describe AmberLSP::Rules::Jobs::PerformRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Jobs::PerformRule.new)
  end

  describe "#check" do
    it "produces no diagnostics when job class defines perform" do
      content = <<-CRYSTAL
      class EmailJob < Amber::Jobs::Job
        def perform
          Mailer.send_email
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Jobs::PerformRule.new
      diagnostics = rule.check("src/jobs/email_job.cr", content)
      diagnostics.should be_empty
    end

    it "reports error when job class is missing perform method" do
      content = <<-CRYSTAL
      class EmailJob < Amber::Jobs::Job
        def send_email
          Mailer.send_email
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Jobs::PerformRule.new
      diagnostics = rule.check("src/jobs/email_job.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("amber/job-perform")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Error)
      diagnostics[0].message.should contain("EmailJob")
      diagnostics[0].message.should contain("perform")
    end

    it "skips files not in jobs/ directory" do
      content = <<-CRYSTAL
      class EmailJob < Amber::Jobs::Job
        def send_email
          Mailer.send_email
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Jobs::PerformRule.new
      diagnostics = rule.check("src/services/email_job.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for empty files" do
      rule = AmberLSP::Rules::Jobs::PerformRule.new
      diagnostics = rule.check("src/jobs/email_job.cr", "")
      diagnostics.should be_empty
    end

    it "produces no diagnostics for files without job classes" do
      content = <<-CRYSTAL
      class Helper
        def perform
          "not a job"
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Jobs::PerformRule.new
      diagnostics = rule.check("src/jobs/helper.cr", content)
      diagnostics.should be_empty
    end

    it "handles job class with perform method having arguments" do
      content = <<-CRYSTAL
      class EmailJob < Amber::Jobs::Job
        def perform(email : String)
          Mailer.send_email(email)
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Jobs::PerformRule.new
      diagnostics = rule.check("src/jobs/email_job.cr", content)
      diagnostics.should be_empty
    end
  end
end
