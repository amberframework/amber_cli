require "../spec_helper"
require "../../../src/amber_lsp/rules/custom_rule"

describe AmberLSP::Rules::CustomRule do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
  end

  describe "#check" do
    it "matches a basic pattern and returns diagnostics" do
      rule = AmberLSP::Rules::CustomRule.new(
        id: "test/no-puts",
        description: "No puts allowed",
        default_severity: AmberLSP::Rules::Severity::Warning,
        applies_to: ["src/**"],
        pattern: /\bputs\b/,
        message_template: "Avoid 'puts' in production code.",
      )

      content = <<-CRYSTAL
      def index
        puts "hello"
      end
      CRYSTAL

      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("test/no-puts")
      diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Warning)
      diagnostics[0].message.should eq("Avoid 'puts' in production code.")
    end

    it "substitutes capture groups into message template using {0}, {1}" do
      rule = AmberLSP::Rules::CustomRule.new(
        id: "test/capture-groups",
        description: "Capture group substitution test",
        default_severity: AmberLSP::Rules::Severity::Warning,
        applies_to: ["*.cr"],
        pattern: /def\s+(\w+)/,
        message_template: "Found method '{1}' (full match: '{0}').",
      )

      content = "def my_method\nend"
      diagnostics = rule.check("src/app.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].message.should eq("Found method 'my_method' (full match: 'def my_method').")
    end

    it "returns multiple diagnostics for multiple matches" do
      rule = AmberLSP::Rules::CustomRule.new(
        id: "test/no-sleep",
        description: "No sleep allowed",
        default_severity: AmberLSP::Rules::Severity::Error,
        applies_to: ["*.cr"],
        pattern: /\bsleep\b/,
        message_template: "Found 'sleep' call.",
      )

      content = <<-CRYSTAL
      sleep 1
      puts "hi"
      sleep 2
      CRYSTAL

      diagnostics = rule.check("src/app.cr", content)
      diagnostics.size.should eq(2)
      diagnostics[0].range.start.line.should eq(0)
      diagnostics[1].range.start.line.should eq(2)
    end

    it "returns empty diagnostics when pattern does not match" do
      rule = AmberLSP::Rules::CustomRule.new(
        id: "test/no-puts",
        description: "No puts allowed",
        default_severity: AmberLSP::Rules::Severity::Warning,
        applies_to: ["*.cr"],
        pattern: /\bputs\b/,
        message_template: "Avoid 'puts'.",
      )

      content = "def index\n  render(\"index.ecr\")\nend"
      diagnostics = rule.check("src/app.cr", content)
      diagnostics.should be_empty
    end

    it "returns empty diagnostics for an empty file" do
      rule = AmberLSP::Rules::CustomRule.new(
        id: "test/no-puts",
        description: "No puts allowed",
        default_severity: AmberLSP::Rules::Severity::Warning,
        applies_to: ["*.cr"],
        pattern: /\bputs\b/,
        message_template: "Avoid 'puts'.",
      )

      diagnostics = rule.check("src/app.cr", "")
      diagnostics.should be_empty
    end

    it "skips files that do not match applies_to patterns" do
      rule = AmberLSP::Rules::CustomRule.new(
        id: "test/no-puts",
        description: "No puts allowed",
        default_severity: AmberLSP::Rules::Severity::Warning,
        applies_to: ["src/controllers/*"],
        pattern: /\bputs\b/,
        message_template: "Avoid 'puts'.",
      )

      content = "puts \"hello\""
      diagnostics = rule.check("spec/models/user_spec.cr", content)
      diagnostics.should be_empty
    end

    it "matches files that satisfy applies_to patterns" do
      rule = AmberLSP::Rules::CustomRule.new(
        id: "test/no-puts",
        description: "No puts allowed",
        default_severity: AmberLSP::Rules::Severity::Warning,
        applies_to: ["src/controllers/*"],
        pattern: /\bputs\b/,
        message_template: "Avoid 'puts'.",
      )

      content = "puts \"hello\""
      diagnostics = rule.check("src/controllers/home_controller.cr", content)
      diagnostics.size.should eq(1)
    end

    it "correctly positions diagnostic ranges" do
      rule = AmberLSP::Rules::CustomRule.new(
        id: "test/detect-todo",
        description: "Detect TODO comments",
        default_severity: AmberLSP::Rules::Severity::Information,
        applies_to: ["*.cr"],
        pattern: /TODO/,
        message_template: "Found TODO comment.",
      )

      content = "# Some comment\n# TODO: fix this\ndef foo\nend"
      diagnostics = rule.check("src/app.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].range.start.line.should eq(1)
      diagnostics[0].range.start.character.should eq(2)
      diagnostics[0].range.end.line.should eq(1)
      diagnostics[0].range.end.character.should eq(6)
    end
  end

  describe "negate mode" do
    it "reports a diagnostic when the pattern is NOT found in the file" do
      rule = AmberLSP::Rules::CustomRule.new(
        id: "test/require-copyright",
        description: "Require copyright header",
        default_severity: AmberLSP::Rules::Severity::Information,
        applies_to: ["*.cr"],
        pattern: /^# Copyright/,
        message_template: "Missing copyright header.",
        negate: true,
      )

      content = "def foo\n  42\nend"
      diagnostics = rule.check("src/app.cr", content)
      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("test/require-copyright")
      diagnostics[0].message.should eq("Missing copyright header.")
      diagnostics[0].range.start.line.should eq(0)
      diagnostics[0].range.start.character.should eq(0)
    end

    it "returns no diagnostics when the pattern IS found in the file" do
      rule = AmberLSP::Rules::CustomRule.new(
        id: "test/require-copyright",
        description: "Require copyright header",
        default_severity: AmberLSP::Rules::Severity::Information,
        applies_to: ["*.cr"],
        pattern: /^# Copyright/,
        message_template: "Missing copyright header.",
        negate: true,
      )

      content = "# Copyright 2026 Amber Framework\ndef foo\n  42\nend"
      diagnostics = rule.check("src/app.cr", content)
      diagnostics.should be_empty
    end

    it "reports a diagnostic for an empty file in negate mode" do
      rule = AmberLSP::Rules::CustomRule.new(
        id: "test/require-copyright",
        description: "Require copyright header",
        default_severity: AmberLSP::Rules::Severity::Information,
        applies_to: ["*.cr"],
        pattern: /^# Copyright/,
        message_template: "Missing copyright header.",
        negate: true,
      )

      diagnostics = rule.check("src/app.cr", "")
      diagnostics.size.should eq(1)
      diagnostics[0].message.should eq("Missing copyright header.")
    end

    it "respects applies_to filtering in negate mode" do
      rule = AmberLSP::Rules::CustomRule.new(
        id: "test/require-copyright",
        description: "Require copyright header",
        default_severity: AmberLSP::Rules::Severity::Information,
        applies_to: ["src/**"],
        pattern: /^# Copyright/,
        message_template: "Missing copyright header.",
        negate: true,
      )

      # File path does not match applies_to, so should return nothing
      diagnostics = rule.check("spec/app_spec.cr", "def foo\nend")
      diagnostics.should be_empty
    end
  end

  describe "integration with RuleRegistry" do
    it "works correctly when registered with RuleRegistry" do
      rule = AmberLSP::Rules::CustomRule.new(
        id: "custom/no-puts",
        description: "No puts allowed",
        default_severity: AmberLSP::Rules::Severity::Warning,
        applies_to: ["*.cr"],
        pattern: /\bputs\b/,
        message_template: "Avoid 'puts'.",
      )

      AmberLSP::Rules::RuleRegistry.register(rule)

      rules = AmberLSP::Rules::RuleRegistry.rules_for_file("src/app.cr")
      rules.size.should eq(1)
      rules[0].id.should eq("custom/no-puts")
    end
  end
end
