require "./spec_helper"
require "../../src/amber_lsp/rules/controllers/naming_rule"
require "../../src/amber_lsp/rules/fsdd/method_type_signature_rule"
require "../../src/amber_lsp/analyze_file_with_coverage"

describe AmberLSP::AnalyzeFileWithCoverage do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
  end

  describe "#perform" do
    it "returns Covered with diagnostics for an Amber project" do
      with_tempdir do |project|
        Dir.mkdir_p(File.join(project, "src/controllers"))
        File.write(File.join(project, "shard.yml"), <<-YAML)
          name: amber_lsp_coverage_spec
          version: 0.1.0
          dependencies:
            amber:
              github: amberframework/amber
        YAML

        file_path = File.join(project, "src/controllers/users_controller.cr")
        File.write(file_path, "class UsersHandler < Amber::Controller::Base\nend\n")
        AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::NamingRule.new)

        coverage = AmberLSP::AnalyzeFileWithCoverage.new(file_path).perform

        coverage.should be_a(AmberLSP::Coverage::Covered)
        if covered = coverage.as?(AmberLSP::Coverage::Covered)
          covered.list_of_diagnostics.map(&.code).should contain("amber/controller-naming")
        end
      end
    end

    it "covers a Grant-only project and runs FSDD rules there" do
      with_tempdir do |project|
        Dir.mkdir_p(File.join(project, "src/models"))
        File.write(File.join(project, "shard.yml"), "name: grant\nversion: 0.1.0\n")
        file_path = File.join(project, "src/models/account.cr")
        content = "def label\n  \"account\"\nend\n"
        File.write(file_path, content)
        AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::FSDD::MethodTypeSignatureRule.new)

        coverage = AmberLSP::AnalyzeFileWithCoverage.new(file_path).perform

        coverage.should be_a(AmberLSP::Coverage::Covered)
        if covered = coverage.as?(AmberLSP::Coverage::Covered)
          covered.list_of_diagnostics.map(&.code).should contain("fsdd/method-type-signature")
        end
      end
    end

    it "returns Declined with a reason for a project outside the stack" do
      with_tempdir do |project|
        File.write(File.join(project, "shard.yml"), "name: plain_crystal_app\nversion: 0.1.0\n")
        file_path = File.join(project, "main.cr")
        File.write(file_path, "puts \"hello\"\n")

        coverage = AmberLSP::AnalyzeFileWithCoverage.new(file_path).perform

        coverage.should be_a(AmberLSP::Coverage::Declined)
        if declined = coverage.as?(AmberLSP::Coverage::Declined)
          declined.reason.should contain("stack")
        end
      end
    end

    it "returns Failed with the parse error for an invalid shard manifest" do
      with_tempdir do |project|
        File.write(File.join(project, "shard.yml"), "{{invalid yaml")
        file_path = File.join(project, "main.cr")
        File.write(file_path, "puts \"hello\"\n")

        coverage = AmberLSP::AnalyzeFileWithCoverage.new(file_path).perform

        coverage.should be_a(AmberLSP::Coverage::Failed)
        if failed = coverage.as?(AmberLSP::Coverage::Failed)
          failed.error.should contain("shard.yml")
        end
      end
    end
  end
end
