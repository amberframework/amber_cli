require "./spec_helper"
require "../../src/amber_lsp/rules/custom_rule"

describe "Custom Rules Integration" do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
  end

  describe "Configuration parsing" do
    it "parses custom_rules from YAML" do
      yaml = <<-YAML
      custom_rules:
        - id: "project/no-puts"
          description: "Do not use puts in production code"
          severity: warning
          applies_to: ["src/**"]
          pattern: "\\\\bputs\\\\b"
          message: "Avoid 'puts' in production code."
      YAML

      config = AmberLSP::Configuration.parse(yaml)
      config.custom_rules.size.should eq(1)
      config.custom_rules[0].id.should eq("project/no-puts")
      config.custom_rules[0].description.should eq("Do not use puts in production code")
      config.custom_rules[0].severity.should eq("warning")
      config.custom_rules[0].applies_to.should eq(["src/**"])
      config.custom_rules[0].negate?.should be_false
    end

    it "parses custom_rules with negate flag" do
      yaml = <<-YAML
      custom_rules:
        - id: "project/require-copyright"
          description: "Every file must have a copyright header"
          severity: info
          applies_to: ["src/**"]
          pattern: "^# Copyright"
          negate: true
          message: "Missing copyright header."
      YAML

      config = AmberLSP::Configuration.parse(yaml)
      config.custom_rules.size.should eq(1)
      config.custom_rules[0].negate?.should be_true
    end

    it "parses multiple custom_rules" do
      yaml = <<-YAML
      custom_rules:
        - id: "project/no-puts"
          description: "No puts"
          severity: warning
          pattern: "\\\\bputs\\\\b"
          message: "No puts allowed."
        - id: "project/no-sleep"
          description: "No sleep"
          severity: error
          pattern: "\\\\bsleep\\\\b"
          message: "No sleep allowed."
      YAML

      config = AmberLSP::Configuration.parse(yaml)
      config.custom_rules.size.should eq(2)
      config.custom_rules[0].id.should eq("project/no-puts")
      config.custom_rules[1].id.should eq("project/no-sleep")
    end

    it "returns empty custom_rules when section is absent" do
      yaml = <<-YAML
      rules:
        amber/model-naming:
          enabled: true
      YAML

      config = AmberLSP::Configuration.parse(yaml)
      config.custom_rules.should be_empty
    end

    it "skips malformed custom_rules entries missing required fields" do
      yaml = <<-YAML
      custom_rules:
        - description: "Missing id and pattern"
          severity: warning
          message: "Should be skipped."
        - id: "project/valid-rule"
          pattern: "\\\\bputs\\\\b"
          message: "This one is valid."
      YAML

      config = AmberLSP::Configuration.parse(yaml)
      config.custom_rules.size.should eq(1)
      config.custom_rules[0].id.should eq("project/valid-rule")
    end

    it "uses default applies_to when not specified" do
      yaml = <<-YAML
      custom_rules:
        - id: "project/no-puts"
          pattern: "\\\\bputs\\\\b"
          message: "No puts."
      YAML

      config = AmberLSP::Configuration.parse(yaml)
      config.custom_rules[0].applies_to.should eq(["src/**"])
    end
  end

  describe "Analyzer with custom rules" do
    it "loads custom rules from config and produces diagnostics" do
      with_tempdir do |dir|
        yaml = <<-YAML
        custom_rules:
          - id: "project/no-puts"
            description: "No puts allowed"
            severity: warning
            applies_to: ["*.cr"]
            pattern: "\\\\bputs\\\\b"
            message: "Avoid 'puts' in production code."
        YAML

        File.write(File.join(dir, ".amber-lsp.yml"), yaml)

        analyzer = AmberLSP::Analyzer.new
        ctx = AmberLSP::ProjectContext.new(dir, amber_project: true)
        analyzer.configure(ctx)

        content = "puts \"hello world\""
        diagnostics = analyzer.analyze("src/app.cr", content)

        diagnostics.size.should eq(1)
        diagnostics[0].code.should eq("project/no-puts")
        diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Warning)
        diagnostics[0].message.should eq("Avoid 'puts' in production code.")
      end
    end

    it "loads negated custom rules from config" do
      with_tempdir do |dir|
        yaml = <<-YAML
        custom_rules:
          - id: "project/require-copyright"
            description: "Every file must have a copyright header"
            severity: info
            applies_to: ["*.cr"]
            pattern: "^# Copyright"
            negate: true
            message: "Missing copyright header."
        YAML

        File.write(File.join(dir, ".amber-lsp.yml"), yaml)

        analyzer = AmberLSP::Analyzer.new
        ctx = AmberLSP::ProjectContext.new(dir, amber_project: true)
        analyzer.configure(ctx)

        content = "def foo\n  42\nend"
        diagnostics = analyzer.analyze("src/app.cr", content)

        diagnostics.size.should eq(1)
        diagnostics[0].code.should eq("project/require-copyright")
        diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Information)
      end
    end

    it "custom rules can be disabled via rule configs" do
      with_tempdir do |dir|
        yaml = <<-YAML
        rules:
          project/no-puts:
            enabled: false
        custom_rules:
          - id: "project/no-puts"
            description: "No puts allowed"
            severity: warning
            applies_to: ["*.cr"]
            pattern: "\\\\bputs\\\\b"
            message: "Avoid 'puts'."
        YAML

        File.write(File.join(dir, ".amber-lsp.yml"), yaml)

        analyzer = AmberLSP::Analyzer.new
        ctx = AmberLSP::ProjectContext.new(dir, amber_project: true)
        analyzer.configure(ctx)

        content = "puts \"hello\""
        diagnostics = analyzer.analyze("src/app.cr", content)
        diagnostics.should be_empty
      end
    end

    it "custom rules severity can be overridden via rule configs" do
      with_tempdir do |dir|
        yaml = <<-YAML
        rules:
          project/no-puts:
            severity: error
        custom_rules:
          - id: "project/no-puts"
            description: "No puts allowed"
            severity: warning
            applies_to: ["*.cr"]
            pattern: "\\\\bputs\\\\b"
            message: "Avoid 'puts'."
        YAML

        File.write(File.join(dir, ".amber-lsp.yml"), yaml)

        analyzer = AmberLSP::Analyzer.new
        ctx = AmberLSP::ProjectContext.new(dir, amber_project: true)
        analyzer.configure(ctx)

        content = "puts \"hello\""
        diagnostics = analyzer.analyze("src/app.cr", content)

        diagnostics.size.should eq(1)
        diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Error)
      end
    end

    it "custom rules coexist with built-in rules" do
      # Register a built-in mock rule alongside the custom rule
      AmberLSP::Rules::RuleRegistry.register(BuiltInMockRule.new)

      with_tempdir do |dir|
        yaml = <<-YAML
        custom_rules:
          - id: "project/no-puts"
            description: "No puts allowed"
            severity: warning
            applies_to: ["*.cr"]
            pattern: "\\\\bputs\\\\b"
            message: "Avoid 'puts'."
        YAML

        File.write(File.join(dir, ".amber-lsp.yml"), yaml)

        analyzer = AmberLSP::Analyzer.new
        ctx = AmberLSP::ProjectContext.new(dir, amber_project: true)
        analyzer.configure(ctx)

        # Content that triggers both the built-in rule and the custom rule
        content = "puts bad_pattern"
        diagnostics = analyzer.analyze("src/app.cr", content)

        codes = diagnostics.map(&.code)
        codes.should contain("builtin/mock-rule")
        codes.should contain("project/no-puts")
      end
    end
  end
end

# A simple built-in mock rule for coexistence testing
class BuiltInMockRule < AmberLSP::Rules::BaseRule
  def id : String
    "builtin/mock-rule"
  end

  def description : String
    "A built-in mock rule"
  end

  def default_severity : AmberLSP::Rules::Severity
    AmberLSP::Rules::Severity::Warning
  end

  def applies_to : Array(String)
    ["*.cr"]
  end

  def check(file_path : String, content : String) : Array(AmberLSP::Rules::Diagnostic)
    diagnostics = [] of AmberLSP::Rules::Diagnostic
    if content.includes?("bad_pattern")
      diagnostics << AmberLSP::Rules::Diagnostic.new(
        range: AmberLSP::Rules::TextRange.new(
          AmberLSP::Rules::Position.new(0, 0),
          AmberLSP::Rules::Position.new(0, 11)
        ),
        severity: default_severity,
        code: id,
        message: "Found bad_pattern"
      )
    end
    diagnostics
  end
end
