require "./spec_helper"
require "../../src/amber_lsp/rules/controllers/naming_rule"
require "../../src/amber_lsp/check_file_for_diagnostics"

describe AmberLSP::CheckFileForDiagnostics do
  before_each do
    AmberLSP::Rules::RuleRegistry.clear
  end

  it "prints a file and line for a real rule violation" do
    with_tempdir do |project|
      Dir.mkdir_p(File.join(project, "src/controllers"))
      file_path = File.join(project, "src/controllers/users_controller.cr")
      File.write(file_path, "class UsersHandler < Amber::Controller::Base\nend\n")
      output = IO::Memory.new
      errors = IO::Memory.new
      File.write(File.join(project, "shard.yml"), <<-YAML)
        name: amber_lsp_check_spec
        version: 0.1.0
        dependencies:
          amber:
            github: amberframework/amber
      YAML
      previous_directory = Dir.current
      begin
        Dir.cd(project)
        AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::NamingRule.new)
        status = AmberLSP::CheckFileForDiagnostics.new(file_path, output, errors).perform
        status.should eq(1)
        output.to_s.lines[0].should eq("amber-lsp: covered 1 diagnostic, 1 error")
        output.to_s.should contain("#{file_path}:1: error: amber/controller-naming")
        errors.to_s.should be_empty
      ensure
        Dir.cd(previous_directory)
      end
    end
  end

  it "reports a missing file as a check error" do
    with_tempdir do |project|
      output = IO::Memory.new
      errors = IO::Memory.new
      status = AmberLSP::CheckFileForDiagnostics.new(File.join(project, "missing.cr"), output, errors).perform
      status.should eq(2)
      output.to_s.should start_with("amber-lsp: failed ")
      errors.to_s.should be_empty
    end
  end

  it "returns zero and covered status for a clean covered file" do
    with_tempdir do |project|
      Dir.mkdir_p(File.join(project, "src/controllers"))
      File.write(File.join(project, "shard.yml"), <<-YAML)
        name: amber_lsp_check_spec
        version: 0.1.0
        dependencies:
          amber:
            github: amberframework/amber
      YAML
      file_path = File.join(project, "src/controllers/posts_controller.cr")
      File.write(file_path, "class PostsController < Amber::Controller::Base\nend\n")
      AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::NamingRule.new)
      output = IO::Memory.new
      errors = IO::Memory.new

      status = AmberLSP::CheckFileForDiagnostics.new(file_path, output, errors).perform

      status.should eq(0)
      output.to_s.should eq("amber-lsp: covered no diagnostics\n")
      errors.to_s.should be_empty
    end
  end

  it "returns two and declined status for a project outside the stack" do
    with_tempdir do |project|
      File.write(File.join(project, "shard.yml"), "name: plain_crystal_app\nversion: 0.1.0\n")
      file_path = File.join(project, "main.cr")
      File.write(file_path, "puts \"hello\"\n")
      output = IO::Memory.new
      errors = IO::Memory.new

      status = AmberLSP::CheckFileForDiagnostics.new(file_path, output, errors).perform

      status.should eq(2)
      output.to_s.should eq("amber-lsp: declined project is not an Amber V2 stack project\n")
      errors.to_s.should be_empty
    end
  end

  it "returns two and failed status for an invalid shard manifest" do
    with_tempdir do |project|
      File.write(File.join(project, "shard.yml"), "{{invalid yaml")
      file_path = File.join(project, "main.cr")
      File.write(file_path, "puts \"hello\"\n")
      output = IO::Memory.new
      errors = IO::Memory.new

      status = AmberLSP::CheckFileForDiagnostics.new(file_path, output, errors).perform

      status.should eq(2)
      output.to_s.should start_with("amber-lsp: failed shard.yml")
      errors.to_s.should be_empty
    end
  end
end
