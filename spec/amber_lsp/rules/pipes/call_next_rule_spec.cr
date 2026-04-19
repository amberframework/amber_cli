require "../../spec_helper"
require "../../../../src/amber_lsp/rules/pipes/call_next_rule"

describe AmberLSP::Rules::Pipes::CallNextRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Pipes::CallNextRule.new)
  end

  describe "#check" do
    it "produces no diagnostics when pipe call method invokes call_next" do
      content = <<-CRYSTAL
      class AuthPipe < Amber::Pipe::Base
        def call(context)
          if authenticated?(context)
            call_next(context)
          else
            context.response.status_code = 401
          end
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Pipes::CallNextRule.new
      diagnostics = rule.check("src/pipes/auth_pipe.cr", content)
      diagnostics.should be_empty
    end

    it "reports error when pipe call method does not invoke call_next" do
      content = <<-CRYSTAL
      class AuthPipe < Amber::Pipe::Base
        def call(context)
          context.response.status_code = 200
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Pipes::CallNextRule.new
      diagnostics = rule.check("src/pipes/auth_pipe.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("amber/pipe-call-next")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Error)
      diagnostics[0].message.should contain("call_next")
      diagnostics[0].message.should contain("pipeline")
    end

    it "produces no diagnostics for files without pipe classes" do
      content = <<-CRYSTAL
      class HomeController < ApplicationController
        def call
          render("index.ecr")
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Pipes::CallNextRule.new
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.should be_empty
    end

    it "produces no diagnostics for empty files" do
      rule = AmberLSP::Rules::Pipes::CallNextRule.new
      diagnostics = rule.check("src/pipes/auth_pipe.cr", "")
      diagnostics.should be_empty
    end

    it "produces no diagnostics for pipe classes that do not override call" do
      content = <<-CRYSTAL
      class SimplePipe < Amber::Pipe::Base
        def some_helper
          "helper"
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Pipes::CallNextRule.new
      diagnostics = rule.check("src/pipes/simple_pipe.cr", content)
      diagnostics.should be_empty
    end

    it "correctly handles call_next inside conditional blocks" do
      content = <<-CRYSTAL
      class AuthPipe < Amber::Pipe::Base
        def call(context)
          if context.valid?
            call_next(context)
          end
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Pipes::CallNextRule.new
      diagnostics = rule.check("src/pipes/auth_pipe.cr", content)
      diagnostics.should be_empty
    end

    it "positions the diagnostic on the call method definition" do
      content = <<-CRYSTAL
      class AuthPipe < Amber::Pipe::Base
        def call(context)
          context.response.status_code = 200
        end
      end
      CRYSTAL

      rule = AmberLSP::Rules::Pipes::CallNextRule.new
      diagnostics = rule.check("src/pipes/auth_pipe.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].range.start.line.should eq(1)
    end
  end
end
