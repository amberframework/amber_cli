require "spec"
require "../../src/amber_cli"

private def parsed_command(args : Array(String)) : AmberCLI::Commands::McpCommand
  command = AmberCLI::Commands::McpCommand.new("mcp")
  command.option_parser.unknown_args do |unknown_args, _|
    command.remaining_arguments.concat(unknown_args)
  end
  command.option_parser.parse(args)
  command
end

describe AmberCLI::Commands::McpCommand do
  describe "registration" do
    it "is reachable as `amber mcp`" do
      AmberCLI::Core::CommandRegistry.find_command("mcp").should eq(AmberCLI::Commands::McpCommand)
    end
  end

  describe "#setup_command_options" do
    it "defaults to the loopback endpoint on port 5757" do
      command = parsed_command(["serve"])

      command.host.should eq("127.0.0.1")
      command.port.should eq(5757)
      command.allow_remote?.should be_false
      command.remaining_arguments.should eq(["serve"])
    end

    it "accepts --host and --port" do
      command = parsed_command(["serve", "--host=127.0.0.1", "--port=9999"])

      command.host.should eq("127.0.0.1")
      command.port.should eq(9999)
    end

    it "accepts --allow-remote" do
      parsed_command(["serve", "--allow-remote"]).allow_remote?.should be_true
    end
  end

  describe "#validate_bind!" do
    it "refuses --host 0.0.0.0 without --allow-remote" do
      command = parsed_command(["serve", "--host=0.0.0.0"])

      error = expect_raises(AmberCLI::Commands::McpCommand::RemoteBindRefusedError) do
        command.validate_bind!
      end

      error.message.to_s.should contain("Refusing to bind 0.0.0.0")
      error.message.to_s.should contain("no authentication")
      error.message.to_s.should contain("--allow-remote")
    end

    it "refuses a wildcard IPv6 bind without --allow-remote" do
      command = parsed_command(["serve", "--host=::"])

      expect_raises(AmberCLI::Commands::McpCommand::RemoteBindRefusedError) do
        command.validate_bind!
      end
    end

    it "permits 0.0.0.0 once --allow-remote is given" do
      command = parsed_command(["serve", "--host=0.0.0.0", "--allow-remote"])

      command.validate_bind!
    end

    it "permits the loopback default" do
      parsed_command(["serve"]).validate_bind!
    end
  end
end
