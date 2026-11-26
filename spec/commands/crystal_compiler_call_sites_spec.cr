require "../amber_cli_spec"
require "../../src/amber_cli/commands/database"
require "../../src/amber_cli/commands/watch"

private def with_crystal_value(crystal_value : String?, &)
  original_crystal_value = ENV["CRYSTAL"]?
  ENV["CRYSTAL"] = crystal_value
  begin
    yield
  ensure
    ENV["CRYSTAL"] = original_crystal_value
  end
end

describe "commands that run the Crystal compiler" do
  it "seeds the database with the compiler named by CRYSTAL" do
    with_crystal_value(" /opt/tools/crystal-alpha ") do
      AmberCLI::Commands::DatabaseCommand.new("database").seed_command
        .should eq("/opt/tools/crystal-alpha run db/seeds.cr")
    end
  end

  it "builds in amber watch with the compiler named by CRYSTAL" do
    with_crystal_value("custom-crystal") do
      SpecHelper.within_temp_directory do
        command = AmberCLI::Commands::WatchCommand.new("watch")
        command.parse_and_execute(["--info"])

        command.build_command.should start_with("custom-crystal build src/")
      end
    end
  end

  it "builds in the default watch config with the compiler named by CRYSTAL" do
    with_crystal_value("custom-crystal") do
      SpecHelper.within_temp_directory do
        list_of_build_commands = Amber::CLI::Config.new.watch["run"]["build_commands"]

        list_of_build_commands.any?(&.starts_with?("custom-crystal build ./src/")).should be_true
        list_of_build_commands.none?(&.starts_with?("crystal build")).should be_true
      end
    end
  end

  it "quotes a CRYSTAL path that contains spaces" do
    with_crystal_value("/opt/my tools/crystal-alpha") do
      AmberCLI::Commands::DatabaseCommand.new("database").seed_command
        .should eq("'/opt/my tools/crystal-alpha' run db/seeds.cr")
    end
  end
end
