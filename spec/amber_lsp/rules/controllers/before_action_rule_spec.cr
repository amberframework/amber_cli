require "../../spec_helper"
require "../../../../src/amber_lsp/rules/controllers/before_action_rule"

describe AmberLSP::Rules::Controllers::BeforeActionRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::BeforeActionRule.new)
  end

  describe "#check" do
    it "produces no diagnostics for correct Amber filter syntax" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        before_action do
          redirect_to "/" unless logged_in?
        end

        def index
          render("index.ecr")
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::BeforeActionRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.should be_empty
    end

    it "reports error for Rails-style before_action with symbol" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        before_action :authenticate_user

        def index
          render("index.ecr")
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::BeforeActionRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("amber/filter-syntax")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Error)
      diagnostics[0].message.should contain("before_action :authenticate_user")
      diagnostics[0].message.should contain("block syntax")
    end

    it "reports error for Rails-style after_action with symbol" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        after_action :log_activity

        def index
          render("index.ecr")
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::BeforeActionRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("after_action :log_activity")
    end

    it "reports error for deprecated before_filter" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        before_filter :authenticate

        def index
          render("index.ecr")
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::BeforeActionRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("before_filter")
      diagnostics[0].message.should contain("deprecated")
      diagnostics[0].message.should contain("before_action")
    end

    it "reports error for deprecated after_filter" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        after_filter :log_it

        def index
          render("index.ecr")
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::BeforeActionRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("after_filter")
      diagnostics[0].message.should contain("deprecated")
      diagnostics[0].message.should contain("after_action")
    end

    it "skips files not in controllers/ directory" do
      content = <<-CRYSTAL
      class SomeClass
        before_action :something
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::BeforeActionRule.new
      diagnostics = rule.check("src/models/some_class.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for empty files" do
      rule = AmberLSP::Rules::Controllers::BeforeActionRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", "")
      diagnostics.should be_empty
    end

    it "reports multiple violations in the same file" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        before_action :authenticate
        after_action :log_activity
        before_filter :old_method

        def index
          render("index.ecr")
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::BeforeActionRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.size.should eq(3)
    end
  end
end
