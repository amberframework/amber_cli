require "../spec_helper"
require "../../../src/amber_lsp/rules/fsdd/process_manager_structure_rule"

describe AmberLSP::Rules::FSDD::ProcessManagerStructureRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::FSDD::ProcessManagerStructureRule.new)
  end

  describe "#check" do
    it "returns empty for files outside process_managers or processes directories" do
      rule = AmberLSP::Rules::FSDD::ProcessManagerStructureRule.new
      diagnostics = rule.check("src/models/user.cr", "class Foo\nend\n")
      diagnostics.should be_empty
    end

    it "flags a class missing initialize" do
      rule = AmberLSP::Rules::FSDD::ProcessManagerStructureRule.new
      content = <<-CRYSTAL
      class Billing::LockAccounts
        def perform : Void
        end
      end
      CRYSTAL
      diagnostics = rule.check("src/process_managers/billing/lock_accounts.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("fsdd/process-manager-structure")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Warning)
      diagnostics[0].message.should contain("LockAccounts")
      diagnostics[0].message.should contain("missing initialize with typed parameters")
    end

    it "flags a class missing a public perform or call method" do
      rule = AmberLSP::Rules::FSDD::ProcessManagerStructureRule.new
      content = <<-CRYSTAL
      class Billing::LockAccounts
        def initialize(@account_id : Int32)
        end
      end
      CRYSTAL
      diagnostics = rule.check("src/process_managers/billing/lock_accounts.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("missing public perform or call method")
    end

    it "reports both issues when both are missing" do
      rule = AmberLSP::Rules::FSDD::ProcessManagerStructureRule.new
      content = "class Billing::LockAccounts\nend\n"
      diagnostics = rule.check("src/process_managers/billing/lock_accounts.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("missing initialize with typed parameters")
      diagnostics[0].message.should contain("missing public perform or call method")
    end

    it "stays quiet when class has typed initialize and public perform" do
      rule = AmberLSP::Rules::FSDD::ProcessManagerStructureRule.new
      content = <<-CRYSTAL
      class Billing::LockAccounts
        def initialize(@account_id : Int32, @reason : String)
        end

        def perform : Void
        end
      end
      CRYSTAL
      diagnostics = rule.check("src/process_managers/billing/lock_accounts.cr", content)
      diagnostics.should be_empty
    end

    it "stays quiet when class uses call instead of perform" do
      rule = AmberLSP::Rules::FSDD::ProcessManagerStructureRule.new
      content = <<-CRYSTAL
      class Users::CreateUser
        def initialize(@email : String)
        end

        def call : Void
        end
      end
      CRYSTAL
      diagnostics = rule.check("src/process_managers/users/create_user.cr", content)
      diagnostics.should be_empty
    end

    it "flags a class whose initialize has no typed parameters" do
      rule = AmberLSP::Rules::FSDD::ProcessManagerStructureRule.new
      content = <<-CRYSTAL
      class Billing::LockAccounts
        def initialize(account_id, reason)
        end

        def perform : Void
        end
      end
      CRYSTAL
      diagnostics = rule.check("src/process_managers/billing/lock_accounts.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("missing initialize with typed parameters")
    end

    it "flags a class whose perform method is private" do
      rule = AmberLSP::Rules::FSDD::ProcessManagerStructureRule.new
      content = <<-CRYSTAL
      class Billing::LockAccounts
        def initialize(@account_id : Int32)
        end

        private def perform : Void
        end
      end
      CRYSTAL
      diagnostics = rule.check("src/process_managers/billing/lock_accounts.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("missing public perform or call method")
    end

    it "also applies to files under processes/ directory" do
      rule = AmberLSP::Rules::FSDD::ProcessManagerStructureRule.new
      content = <<-CRYSTAL
      class Billing::RetryPayments
        def perform : Void
        end
      end
      CRYSTAL
      diagnostics = rule.check("src/processes/billing/retry_payments.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("missing initialize with typed parameters")
    end
  end
end
