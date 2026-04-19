require "../../spec_helper"
require "../../../../src/amber_lsp/rules/controllers/inheritance_rule"

describe AmberLSP::Rules::Controllers::InheritanceRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::InheritanceRule.new)
  end

  describe "#check" do
    it "produces no diagnostics when inheriting from ApplicationController" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        def index
          render("index.ecr")
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::InheritanceRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics when inheriting from Amber::Controller::Base" do
      content = <<-CRYSTAL
      class HomeController < Amber::Controller::Base
        def index
          render("index.ecr")
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::InheritanceRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.should be_empty
    end

    it "reports error when inheriting from an invalid base class" do
      content = <<-CRYSTAL
      class HomeController < SomeOtherBase
        def index
          render("index.ecr")
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::InheritanceRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("amber/controller-inheritance")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Error)
      diagnostics[0].message.should contain("SomeOtherBase")
      diagnostics[0].message.should contain("ApplicationController")
    end

    it "skips application_controller.cr file" do
      content = <<-CRYSTAL
      class ApplicationController < Amber::Controller::Base
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::InheritanceRule.new
      diagnostics = rule.check("src/controllers/application_controller.cr", content)
      diagnostics.should be_empty
    end

    it "skips files not in controllers/ directory" do
      content = <<-CRYSTAL
      class HomeController < SomeOtherBase
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::InheritanceRule.new
      diagnostics = rule.check("src/models/home.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for empty files" do
      rule = AmberLSP::Rules::Controllers::InheritanceRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", "")
      diagnostics.should be_empty
    end

    it "handles multiple controller classes in one file" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
      end

      class AdminController < WrongBase
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::InheritanceRule.new
      diagnostics = rule.check("src/controllers/controllers.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("WrongBase")
    end

    it "only checks classes whose names end in Controller" do
      content = <<-CRYSTAL
      class Helper < SomeBase
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::InheritanceRule.new
      diagnostics = rule.check("src/controllers/helper.cr", content)
      diagnostics.should be_empty
    end
  end
end
