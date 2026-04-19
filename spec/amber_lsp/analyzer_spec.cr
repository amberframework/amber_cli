require "./spec_helper"

# A mock rule for testing the analyzer
class MockTestRule < AmberLSP::Rules::BaseRule
  def id : String
    "mock/test-rule"
  end

  def description : String
    "A mock rule for testing"
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

# A mock rule that only applies to controller files
class MockControllerRule < AmberLSP::Rules::BaseRule
  def id : String
    "mock/controller-rule"
  end

  def description : String
    "A mock controller rule"
  end

  def default_severity : AmberLSP::Rules::Severity
    AmberLSP::Rules::Severity::Error
  end

  def applies_to : Array(String)
    ["*_controller.cr"]
  end

  def check(file_path : String, content : String) : Array(AmberLSP::Rules::Diagnostic)
    [] of AmberLSP::Rules::Diagnostic
  end
end

describe AmberLSP::Analyzer do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
  end

  describe "#analyze" do
    it "returns diagnostics from registered rules" do
      AmberLSP::Rules::RuleRegistry.register(MockTestRule.new)

      analyzer = AmberLSP::Analyzer.new
      diagnostics = analyzer.analyze("src/app.cr", "bad_pattern here")

      diagnostics.size.should eq(1)
      diagnostics[0].code.should eq("mock/test-rule")
      diagnostics[0].message.should eq("Found bad_pattern")
    end

    it "returns empty array when no rules match" do
      AmberLSP::Rules::RuleRegistry.register(MockTestRule.new)

      analyzer = AmberLSP::Analyzer.new
      diagnostics = analyzer.analyze("src/app.cr", "clean code")

      diagnostics.should be_empty
    end

    it "skips excluded files" do
      AmberLSP::Rules::RuleRegistry.register(MockTestRule.new)

      analyzer = AmberLSP::Analyzer.new
      diagnostics = analyzer.analyze("lib/some_shard/bad_pattern.cr", "bad_pattern")

      diagnostics.should be_empty
    end

    it "only runs rules that apply to the file" do
      AmberLSP::Rules::RuleRegistry.register(MockControllerRule.new)

      analyzer = AmberLSP::Analyzer.new
      # Should not trigger controller rule on a model file
      rules = AmberLSP::Rules::RuleRegistry.rules_for_file("src/models/user.cr")
      rules.should be_empty
    end

    it "evaluates exclude patterns relative to the project root" do
      AmberLSP::Rules::RuleRegistry.register(MockTestRule.new)

      with_tempdir do |dir|
        analyzer = AmberLSP::Analyzer.new
        ctx = AmberLSP::ProjectContext.new(dir, amber_project: true)
        analyzer.configure(ctx)

        diagnostics = analyzer.analyze(
          File.join(dir, "src", "controllers", "home_controller.cr"),
          "bad_pattern here"
        )

        diagnostics.size.should eq(1)
        diagnostics[0].code.should eq("mock/test-rule")
      end
    end

    it "still excludes project tmp files when using absolute paths" do
      AmberLSP::Rules::RuleRegistry.register(MockTestRule.new)

      with_tempdir do |dir|
        analyzer = AmberLSP::Analyzer.new
        ctx = AmberLSP::ProjectContext.new(dir, amber_project: true)
        analyzer.configure(ctx)

        diagnostics = analyzer.analyze(
          File.join(dir, "tmp", "cache", "artifact.cr"),
          "bad_pattern here"
        )

        diagnostics.should be_empty
      end
    end

    it "applies severity overrides from configuration" do
      AmberLSP::Rules::RuleRegistry.register(MockTestRule.new)

      yaml = <<-YAML
      rules:
        mock/test-rule:
          enabled: true
          severity: error
      YAML

      with_tempdir do |dir|
        File.write(File.join(dir, ".amber-lsp.yml"), yaml)

        analyzer = AmberLSP::Analyzer.new
        ctx = AmberLSP::ProjectContext.new(dir, amber_project: true)
        analyzer.configure(ctx)

        diagnostics = analyzer.analyze("src/app.cr", "bad_pattern here")

        diagnostics.size.should eq(1)
        diagnostics[0].severity.should eq(AmberLSP::Rules::Severity::Error)
      end
    end

    it "skips disabled rules" do
      AmberLSP::Rules::RuleRegistry.register(MockTestRule.new)

      yaml = <<-YAML
      rules:
        mock/test-rule:
          enabled: false
      YAML

      with_tempdir do |dir|
        File.write(File.join(dir, ".amber-lsp.yml"), yaml)

        analyzer = AmberLSP::Analyzer.new
        ctx = AmberLSP::ProjectContext.new(dir, amber_project: true)
        analyzer.configure(ctx)

        diagnostics = analyzer.analyze("src/app.cr", "bad_pattern here")

        diagnostics.should be_empty
      end
    end
  end
end
