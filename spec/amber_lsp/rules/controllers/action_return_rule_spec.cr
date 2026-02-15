require "../../spec_helper"
require "../../../../src/amber_lsp/rules/controllers/action_return_rule"

describe AmberLSP::Rules::Controllers::ActionReturnRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::ActionReturnRule.new)
  end

  describe "#check" do
    it "produces no diagnostics when actions call render" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        def index
          render("index.ecr")
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::ActionReturnRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics when actions call redirect_to" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        def create
          redirect_to "/home"
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::ActionReturnRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics when actions call redirect_back" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        def back
          redirect_back
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::ActionReturnRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics when actions call respond_with" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        def show
          respond_with do
            json({ name: "test" })
          end
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::ActionReturnRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics when actions call halt!" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        def restricted
          halt!(403, "Forbidden")
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::ActionReturnRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.should be_empty
    end

    it "reports warning when action does not call any response method" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        def index
          @users = User.all
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::ActionReturnRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("amber/action-return-type")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Warning)
      diagnostics[0].message.should contain("index")
      diagnostics[0].message.should contain("render")
    end

    it "skips private methods" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        def index
          render("index.ecr")
        end

        private def helper_method
          "helper"
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::ActionReturnRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.should be_empty
    end

    it "skips methods after private keyword" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        def index
          render("index.ecr")
        end

        private

        def helper_method
          "helper"
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::ActionReturnRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.should be_empty
    end

    it "skips files not in controllers/ directory" do
      content = <<-CRYSTAL
      class SomeService
        def call
          "no render needed"
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::ActionReturnRule.new
      diagnostics = rule.check("src/services/some_service.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for empty files" do
      rule = AmberLSP::Rules::Controllers::ActionReturnRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", "")
      diagnostics.should be_empty
    end

    it "handles multiple actions with mixed compliance" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        def index
          render("index.ecr")
        end

        def show
          @user = User.find(params[:id])
        end

        def create
          redirect_to "/home"
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::ActionReturnRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("show")
    end
  end
end
