require "../amber_cli_spec"
require "../../src/amber_cli/commands/new"

describe AmberCLI::Commands::NewCommand do
  describe "#setup_command_options" do
    it "accepts --type web (default)" do
      command = AmberCLI::Commands::NewCommand.new("new")
      command.app_type.should eq("web")
    end

    it "accepts --type native flag" do
      command = AmberCLI::Commands::NewCommand.new("new")
      args = ["my_app", "--type", "native"]

      command.option_parser.unknown_args do |unknown_args, _|
        command.remaining_arguments.concat(unknown_args)
      end
      command.option_parser.parse(args)

      command.app_type.should eq("native")
      command.remaining_arguments.should eq(["my_app"])
    end

    it "accepts --type=native with equals syntax" do
      command = AmberCLI::Commands::NewCommand.new("new")
      args = ["my_app", "--type=native"]

      command.option_parser.unknown_args do |unknown_args, _|
        command.remaining_arguments.concat(unknown_args)
      end
      command.option_parser.parse(args)

      command.app_type.should eq("native")
    end

    it "accepts --type web explicitly" do
      command = AmberCLI::Commands::NewCommand.new("new")
      args = ["my_app", "--type=web"]

      command.option_parser.unknown_args do |unknown_args, _|
        command.remaining_arguments.concat(unknown_args)
      end
      command.option_parser.parse(args)

      command.app_type.should eq("web")
    end

    it "preserves database and template flags alongside --type" do
      command = AmberCLI::Commands::NewCommand.new("new")
      args = ["my_app", "-d", "sqlite", "-t", "slang", "--type=web"]

      command.option_parser.unknown_args do |unknown_args, _|
        command.remaining_arguments.concat(unknown_args)
      end
      command.option_parser.parse(args)

      command.database.should eq("sqlite")
      command.template.should eq("slang")
      command.app_type.should eq("web")
    end

    it "combines --type native with --no-deps" do
      command = AmberCLI::Commands::NewCommand.new("new")
      args = ["my_app", "--type=native", "--no-deps"]

      command.option_parser.unknown_args do |unknown_args, _|
        command.remaining_arguments.concat(unknown_args)
      end
      command.option_parser.parse(args)

      command.app_type.should eq("native")
      command.no_deps.should be_true
    end
  end
end
