require "../../spec_helper"
require "../../../../src/amber_lsp/rules/jobs/serializable_rule"

describe AmberLSP::Rules::Jobs::SerializableRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Jobs::SerializableRule.new)
  end

  describe "#check" do
    it "produces no diagnostics when job includes JSON::Serializable" do
      content = <<-CRYSTAL
      class EmailJob < Amber::Jobs::Job
        include JSON::Serializable

        property email : String

        def perform
          Mailer.send_email(@email)
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Jobs::SerializableRule.new
      diagnostics = rule.check("src/jobs/email_job.cr", content)
      diagnostics.should be_empty
    end

    it "reports warning when job class is missing JSON::Serializable" do
      content = <<-CRYSTAL
      class EmailJob < Amber::Jobs::Job
        def perform
          Mailer.send_email
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Jobs::SerializableRule.new
      diagnostics = rule.check("src/jobs/email_job.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("amber/job-serializable")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Warning)
      diagnostics[0].message.should contain("EmailJob")
      diagnostics[0].message.should contain("JSON::Serializable")
    end

    it "skips files not in jobs/ directory" do
      content = <<-CRYSTAL
      class EmailJob < Amber::Jobs::Job
        def perform
          Mailer.send_email
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Jobs::SerializableRule.new
      diagnostics = rule.check("src/services/email_job.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for empty files" do
      rule = AmberLSP::Rules::Jobs::SerializableRule.new
      diagnostics = rule.check("src/jobs/email_job.cr", "")
      diagnostics.should be_empty
    end

    it "produces no diagnostics for files without job classes" do
      content = <<-CRYSTAL
      class Helper
        def help
          "not a job"
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Jobs::SerializableRule.new
      diagnostics = rule.check("src/jobs/helper.cr", content)
      diagnostics.should be_empty
    end

    it "detects JSON::Serializable even with extra whitespace" do
      content = <<-CRYSTAL
      class EmailJob < Amber::Jobs::Job
        include   JSON::Serializable

        def perform
          Mailer.send_email
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Jobs::SerializableRule.new
      diagnostics = rule.check("src/jobs/email_job.cr", content)
      diagnostics.should be_empty
    end
  end
end
