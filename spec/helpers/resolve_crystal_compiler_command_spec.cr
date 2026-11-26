require "../amber_cli_spec"
require "../../src/amber_cli/helpers/resolve_crystal_compiler_command"

private def path_with(list_of_commands : Array(String)) : Proc(String, String?)
  ->(command : String) { list_of_commands.includes?(command) ? "/usr/local/bin/#{command}" : nil }
end

describe Amber::CLI::ResolveCrystalCompilerCommand do
  it "runs the compiler named by CRYSTAL" do
    Amber::CLI::ResolveCrystalCompilerCommand.new("acrystal", path_with(["crystal-alpha", "crystal"])).perform.should eq("acrystal")
  end

  it "strips whitespace around the CRYSTAL value" do
    Amber::CLI::ResolveCrystalCompilerCommand.new("  /opt/tools/crystal-alpha\n", path_with(["crystal"])).perform.should eq("/opt/tools/crystal-alpha")
  end

  it "runs crystal-alpha when CRYSTAL is unset and both compilers are on PATH" do
    Amber::CLI::ResolveCrystalCompilerCommand.new(nil, path_with(["crystal", "crystal-alpha"])).perform.should eq("crystal-alpha")
  end

  it "runs crystal when CRYSTAL is unset and crystal-alpha is absent" do
    Amber::CLI::ResolveCrystalCompilerCommand.new(nil, path_with(["crystal"])).perform.should eq("crystal")
  end

  it "treats a blank CRYSTAL as unset" do
    Amber::CLI::ResolveCrystalCompilerCommand.new("  ", path_with(["crystal-alpha"])).perform.should eq("crystal-alpha")
  end
end
