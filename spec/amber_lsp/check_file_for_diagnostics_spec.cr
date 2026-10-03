require "./spec_helper"
require "../../src/amber_lsp/rules/controllers/naming_rule"
require "../../src/amber_lsp/check_file_for_diagnostics"

describe AmberLSP::CheckFileForDiagnostics do
  it "prints a file and line for a real rule violation" do
    with_tempdir do |project|
      Dir.mkdir_p(File.join(project, "src/controllers"))
      file_path = File.join(project, "src/controllers/users_controller.cr")
      File.write(file_path, "class UsersHandler < Amber::Controller::Base\nend\n")
      output = IO::Memory.new
      errors = IO::Memory.new
      previous_directory = Dir.current
      begin
        Dir.cd(project)
        status = AmberLSP::CheckFileForDiagnostics.new(file_path, output, errors).perform
        status.should eq(1)
        output.to_s.should contain("#{file_path}:1: error: amber/controller-naming")
        errors.to_s.should be_empty
      ensure
        Dir.cd(previous_directory)
      end
    end
  end

  it "reports a missing file as a check error" do
    with_tempdir do |project|
      errors = IO::Memory.new
      status = AmberLSP::CheckFileForDiagnostics.new(File.join(project, "missing.cr"), IO::Memory.new, errors).perform
      status.should eq(2)
      errors.to_s.should contain("file not found")
    end
  end
end
