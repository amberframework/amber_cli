require "../../spec_helper"
require "../../../../src/amber_lsp/rules/controllers/naming_rule"

describe AmberLSP::Rules::Controllers::NamingRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::NamingRule.new)
  end

  describe "#check" do
    it "produces no diagnostics for correctly named controller classes" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        def index
          render("index.ecr")
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::NamingRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.should be_empty
    end

    it "reports error when class name does not end with Controller" do
      content = <<-CRYSTAL
      class Home < ApplicationController
        def index
          render("index.ecr")
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::NamingRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("amber/controller-naming")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Error)
      diagnostics[0].message.should contain("Home")
      diagnostics[0].message.should contain("Controller")
    end

    it "skips files not in controllers/ directory" do
      content = <<-CRYSTAL
      class Home < ApplicationController
        def index
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::NamingRule.new
      diagnostics = rule.check("src/models/home.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for empty files" do
      rule = AmberLSP::Rules::Controllers::NamingRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", "")
      diagnostics.should be_empty
    end

    it "handles multiple classes in one file" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        def index
        end
      end

      class Dashboard < ApplicationController
        def show
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::NamingRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("Dashboard")
    end

    it "reports errors for multiple incorrectly named classes" do
      content = <<-CRYSTAL
      class Home < ApplicationController
      end

      class Dashboard < ApplicationController
      end
      CRYSTAL

      rule = AmberLSP::Rules::Controllers::NamingRule.new
      diagnostics = rule.check("src/controllers/misc.cr", content)
      diagnostics.size.should eq(2)
    end

    it "correctly positions the diagnostic range on the class name" do
      content = "class HomeController < ApplicationController\nend"
      rule = AmberLSP::Rules::Controllers::NamingRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.should be_empty

      content_bad = "class Home < ApplicationController\nend"
      diagnostics = rule.check("src/controllers/home.cr", content_bad)
      diagnostics.size.should eq(1)
      diagnostics[0].range.start.line.should eq(0)
    end
  end
end
