require "../spec_helper"
require "../../../src/amber_lsp/lookup/list_homebrew_prefixes_around_compiler"

private def within_temporary_directory(&)
  directory = File.realpath(Dir.tempdir).to_s
  directory = File.join(directory, "amber-lsp-prefix-#{Random::Secure.hex(6)}")
  Dir.mkdir_p(directory)
  begin
    yield directory
  ensure
    FileUtils.rm_rf(directory)
  end
end

private def write_compiler(compiler_path : String) : Nil
  Dir.mkdir_p(File.dirname(compiler_path))
  File.write(compiler_path, "#!/bin/sh\nexit 0\n")
  File.chmod(compiler_path, 0o755)
end

describe AmberLSP::Lookup::ListHomebrewPrefixesAroundCompiler do
  it "finds the prefix from bin, from an opt keg symlink, and from the Cellar path" do
    within_temporary_directory do |prefix|
      cellar_compiler = File.join(prefix, "Cellar", "agent-crystal", "1.0.0", "bin", "crystal-alpha")
      write_compiler(cellar_compiler)
      Dir.mkdir_p(File.join(prefix, "opt"))
      Dir.mkdir_p(File.join(prefix, "bin"))
      File.symlink(File.join(prefix, "Cellar", "agent-crystal", "1.0.0"), File.join(prefix, "opt", "agent-crystal"))
      File.symlink(cellar_compiler, File.join(prefix, "bin", "crystal-alpha"))

      AmberLSP::Lookup::ListHomebrewPrefixesAroundCompiler.new(File.join(prefix, "bin", "crystal-alpha")).perform
        .should eq([prefix])
      AmberLSP::Lookup::ListHomebrewPrefixesAroundCompiler.new(File.join(prefix, "opt", "agent-crystal", "bin", "crystal-alpha")).perform
        .should eq([prefix])
      AmberLSP::Lookup::ListHomebrewPrefixesAroundCompiler.new(cellar_compiler).perform
        .should eq([prefix])
    end
  end

  it "lists no prefix for a compiler outside a Homebrew prefix" do
    within_temporary_directory do |project|
      compiler = File.join(project, "bin", "crystal-alpha")
      write_compiler(compiler)
      Dir.mkdir_p(File.join(project, "opt"))

      AmberLSP::Lookup::ListHomebrewPrefixesAroundCompiler.new(compiler).perform.should be_empty
    end
  end

  it "lists no prefix for a compiler in a system bin folder" do
    AmberLSP::Lookup::ListHomebrewPrefixesAroundCompiler.new("/bin/crystal-alpha").perform.should be_empty
  end
end
