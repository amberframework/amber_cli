require "../spec_helper"
require "../../../src/amber_lsp/lookup/find_llvm_config_for_compiler"

private def no_executables_on_path : Proc(String, String?)
  ->(command : String) { nil.as(String?) }
end

private def within_temporary_directory(&)
  directory = File.join(File.realpath(Dir.tempdir).to_s, "amber-lsp-llvm-#{Random::Secure.hex(6)}")
  Dir.mkdir_p(directory)
  begin
    yield directory
  ensure
    FileUtils.rm_rf(directory)
  end
end

private def write_executable(path : String, body : String) : String
  Dir.mkdir_p(File.dirname(path))
  File.write(path, "#!/bin/sh\n#{body}\n")
  File.chmod(path, 0o755)
  path
end

# Writes an llvm-config that records each run in `run_log` and reports `version`.
private def write_llvm_config(prefix : String, version : String, run_log : String) : String
  write_executable(
    File.join(prefix, "opt", "llvm@21", "bin", "llvm-config"),
    "printf '%s\\n' \"$0\" >> '#{run_log}'\necho #{version}",
  )
end

private def write_homebrew_compiler(prefix : String) : String
  write_executable(File.join(prefix, "Cellar", "agent-crystal", "1.0.0", "bin", "crystal-alpha"), "exit 0")
  Dir.mkdir_p(File.join(prefix, "bin"))
  compiler = File.join(prefix, "bin", "crystal-alpha")
  File.symlink(File.join(prefix, "Cellar", "agent-crystal", "1.0.0", "bin", "crystal-alpha"), compiler)
  compiler
end

private def list_of_runs(run_log : String) : Array(String)
  File.exists?(run_log) ? File.read_lines(run_log) : [] of String
end

describe AmberLSP::Lookup::FindLLVMConfigForCompiler do
  it "matches the LLVM major.minor as whole version components" do
    AmberLSP::Lookup::FindLLVMConfigForCompiler.reports_llvm_version?("21.1.8\n", "21", "1").should be_true
    AmberLSP::Lookup::FindLLVMConfigForCompiler.reports_llvm_version?("21.1\n", "21", "1").should be_true
    AmberLSP::Lookup::FindLLVMConfigForCompiler.reports_llvm_version?("21.10.2\n", "21", "1").should be_false
    AmberLSP::Lookup::FindLLVMConfigForCompiler.reports_llvm_version?("211.1.0\n", "21", "1").should be_false
  end

  it "searches the Homebrew prefix beside the compiler before the standard prefixes" do
    within_temporary_directory do |directory|
      run_log = File.join(directory, "runs.log")
      linuxbrew_prefix = File.join(directory, "linuxbrew")
      standard_prefix = File.join(directory, "standard")
      compiler = write_homebrew_compiler(linuxbrew_prefix)
      beside_compiler = write_llvm_config(linuxbrew_prefix, "21.1.8", run_log)
      write_llvm_config(standard_prefix, "21.1.8", run_log)

      AmberLSP::Lookup::FindLLVMConfigForCompiler.new(compiler, "21.1.8", [standard_prefix], no_executables_on_path).perform
        .should eq(beside_compiler)
      list_of_runs(run_log).should eq([beside_compiler])
    end
  end

  it "finds the unversioned llvm keg beside the compiler when its version matches" do
    within_temporary_directory do |directory|
      run_log = File.join(directory, "runs.log")
      linuxbrew_prefix = File.join(directory, "linuxbrew")
      compiler = write_homebrew_compiler(linuxbrew_prefix)
      unversioned_llvm_config = write_executable(
        File.join(linuxbrew_prefix, "opt", "llvm", "bin", "llvm-config"),
        "echo 21.1.8",
      )

      AmberLSP::Lookup::FindLLVMConfigForCompiler.new(compiler, "21.1.8", ([] of String), no_executables_on_path).perform
        .should eq(unversioned_llvm_config)
    end
  end

  it "skips an llvm-config whose minor version only starts with the wanted one" do
    within_temporary_directory do |directory|
      run_log = File.join(directory, "runs.log")
      linuxbrew_prefix = File.join(directory, "linuxbrew")
      standard_prefix = File.join(directory, "standard")
      compiler = write_homebrew_compiler(linuxbrew_prefix)
      write_llvm_config(linuxbrew_prefix, "21.10.2", run_log)
      standard_llvm_config = write_llvm_config(standard_prefix, "21.1.3", run_log)

      AmberLSP::Lookup::FindLLVMConfigForCompiler.new(compiler, "21.1.8", [standard_prefix], no_executables_on_path).perform
        .should eq(standard_llvm_config)
    end
  end

  it "never runs an llvm-config planted in a project's opt folder" do
    within_temporary_directory do |project|
      run_log = File.join(project, "runs.log")
      compiler = write_executable(File.join(project, "bin", "crystal-alpha"), "exit 0")
      nested_compiler = write_executable(File.join(project, "tools", "crystal", "bin", "crystal-alpha"), "exit 0")
      write_llvm_config(project, "21.1.8", run_log)

      AmberLSP::Lookup::FindLLVMConfigForCompiler.new(compiler, "21.1.8", ([] of String), no_executables_on_path).perform
        .should be_nil
      AmberLSP::Lookup::FindLLVMConfigForCompiler.new(nested_compiler, "21.1.8", ([] of String), no_executables_on_path).perform
        .should be_nil
      list_of_runs(run_log).should be_empty
    end
  end
end
