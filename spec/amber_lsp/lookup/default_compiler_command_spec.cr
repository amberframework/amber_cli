require "../spec_helper"
require "../../../src/amber_lsp/lookup/default_compiler_command"

private def with_compilers_on_path(list_of_compiler_names : Array(String), &)
  directory = File.join(Dir.tempdir, "amber-lsp-compilers-#{Random::Secure.hex(6)}")
  Dir.mkdir_p(directory)
  list_of_compiler_names.each do |compiler_name|
    compiler_path = File.join(directory, compiler_name)
    File.write(compiler_path, "#!/bin/sh\nexit 0\n")
    File.chmod(compiler_path, 0o755)
  end
  original_path = ENV["PATH"]?
  ENV["PATH"] = directory
  begin
    yield
  ensure
    ENV["PATH"] = original_path
    FileUtils.rm_rf(directory)
  end
end

describe "AmberLSP::Lookup.default_compiler_command" do
  it "prefers crystal-alpha when it is installed" do
    with_compilers_on_path(["crystal-alpha", "crystal"]) do
      AmberLSP::Lookup.default_compiler_command.should eq("crystal-alpha")
    end
  end

  it "falls back to stock crystal when crystal-alpha is not installed" do
    with_compilers_on_path(["crystal"]) do
      AmberLSP::Lookup.default_compiler_command.should eq("crystal")
    end
  end
end
