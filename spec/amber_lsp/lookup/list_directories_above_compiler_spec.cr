require "../spec_helper"
require "../../../src/amber_lsp/lookup/build_layered_api_index"

describe AmberLSP::Lookup::ListDirectoriesAboveCompiler do
  it "reaches the Homebrew prefix from a keg's opt symlink and from the resolved Cellar path" do
    prefix = File.join(Dir.tempdir, "amber-lsp-prefix-#{Random::Secure.hex(6)}")
    cellar_bin = File.join(prefix, "Cellar", "agent-crystal", "1.0.0", "bin")
    opt_keg = File.join(prefix, "opt", "agent-crystal")
    begin
      Dir.mkdir_p(cellar_bin)
      File.write(File.join(cellar_bin, "crystal-alpha"), "")
      Dir.mkdir_p(File.join(prefix, "opt"))
      File.symlink(File.join(prefix, "Cellar", "agent-crystal", "1.0.0"), opt_keg)

      list_of_directories = AmberLSP::Lookup::ListDirectoriesAboveCompiler.new(
        File.join(opt_keg, "bin", "crystal-alpha")
      ).perform

      list_of_directories.first.should eq(File.join(opt_keg, "bin"))
      list_of_directories.should contain(prefix)
      list_of_directories.should contain(File.realpath(cellar_bin))
      list_of_directories.should_not contain("/")
    ensure
      FileUtils.rm_rf(prefix)
    end
  end

  it "lists the directories above a compiler path that does not exist" do
    AmberLSP::Lookup::ListDirectoriesAboveCompiler.new("/home/linuxbrew/.linuxbrew/bin/crystal-alpha").perform
      .should eq(["/home/linuxbrew/.linuxbrew/bin", "/home/linuxbrew/.linuxbrew", "/home/linuxbrew", "/home"])
  end
end
