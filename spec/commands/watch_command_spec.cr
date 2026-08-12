require "../amber_cli_spec"
require "../../src/amber_cli/commands/watch"

describe AmberCLI::Commands::WatchCommand do
  it "watches templates and authored assets as part of the default rebuild loop" do
    SpecHelper.within_temp_directory do
      command = AmberCLI::Commands::WatchCommand.new("watch")
      command.parse_and_execute(["--info"])

      command.watch_files.should contain("src/**/*.cr")
      command.watch_files.should contain("src/**/*.ecr")
      command.watch_files.should contain("app/assets/**/*")
    end
  end
end
