require "../spec_helper"
require "../../../src/amber_lsp/rules/fsdd/method_type_signature_rule"

describe AmberLSP::Rules::FSDD::MethodTypeSignatureRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
    AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::FSDD::MethodTypeSignatureRule.new)
  end

  describe "#check" do
    it "flags a method with an untyped parameter" do
      rule = AmberLSP::Rules::FSDD::MethodTypeSignatureRule.new
      diagnostics = rule.check("src/models/user.cr", "def foo(x)\nend\n")
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("fsdd/method-type-signature")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Warning)
      diagnostics[0].message.should contain("foo")
      diagnostics[0].message.should contain("untyped parameter")
    end

    it "flags a method with typed params but no return type" do
      rule = AmberLSP::Rules::FSDD::MethodTypeSignatureRule.new
      diagnostics = rule.check("src/models/user.cr", "def bar(x : Int32)\nend\n")
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("fsdd/method-type-signature")
      diagnostics[0].message.should contain("bar")
      diagnostics[0].message.should contain("missing return type")
    end

    it "stays quiet on a fully typed method" do
      rule = AmberLSP::Rules::FSDD::MethodTypeSignatureRule.new
      diagnostics = rule.check("src/models/user.cr", "def baz(x : Int32) : String\nend\n")
      diagnostics.should be_empty
    end

    it "flags a method with no params and no return type" do
      rule = AmberLSP::Rules::FSDD::MethodTypeSignatureRule.new
      diagnostics = rule.check("src/models/user.cr", "def greet\nend\n")
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("missing return type")
    end

    it "stays quiet on a no-param method with return type" do
      rule = AmberLSP::Rules::FSDD::MethodTypeSignatureRule.new
      diagnostics = rule.check("src/models/user.cr", "def count : Int32\nend\n")
      diagnostics.should be_empty
    end

    it "flags both issues when params are untyped AND return type is missing" do
      rule = AmberLSP::Rules::FSDD::MethodTypeSignatureRule.new
      diagnostics = rule.check("src/services/calculator.cr", "def add(a, b)\nend\n")
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("untyped parameter")
      diagnostics[0].message.should contain("missing return type")
    end

    it "stays quiet on a method with multiple typed params and return type" do
      rule = AmberLSP::Rules::FSDD::MethodTypeSignatureRule.new
      content = "def add(a : Int32, b : Int32) : Int32\nend\n"
      diagnostics = rule.check("src/services/calculator.cr", content)
      diagnostics.should be_empty
    end

    it "skips initialize methods" do
      rule = AmberLSP::Rules::FSDD::MethodTypeSignatureRule.new
      diagnostics = rule.check("src/models/user.cr", "def initialize(@name : String)\nend\n")
      diagnostics.should be_empty
    end

    it "flags a method with a mix of typed and untyped params" do
      rule = AmberLSP::Rules::FSDD::MethodTypeSignatureRule.new
      content = "def process(name, count : Int32) : Bool\nend\n"
      diagnostics = rule.check("src/models/user.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should contain("untyped parameter")
    end

    it "handles multiple methods in one file" do
      rule = AmberLSP::Rules::FSDD::MethodTypeSignatureRule.new
      content = <<-CRYSTAL
      def foo(x : Int32) : String
        x.to_s
      end

      def bar(y)
        y
      end

      def qux
        42
      end
      CRYSTAL
      diagnostics = rule.check("src/models/user.cr", content)
      diagnostics.size.should eq(2)
    end

    it "produces no diagnostics for an empty file" do
      rule = AmberLSP::Rules::FSDD::MethodTypeSignatureRule.new
      diagnostics = rule.check("src/models/user.cr", "")
      diagnostics.should be_empty
    end
  end
end
