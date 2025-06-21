require "../amber_cli_spec"

# Test command implementations for spec purposes
class TestGenerateCommand < AmberCLI::Core::BaseCommand
  def initialize
    super("generate")
    setup_options
  end

  def setup_options
    @option_parser.banner = "Usage: amber generate [generator] [name] [options]"
    @option_parser.on("-f", "--force", "Force overwrite existing files") do
      @parsed_options["force"] = true
    end
    @option_parser.on("-v", "--verbose", "Verbose output") do
      @parsed_options["verbose"] = true
    end
    @option_parser.on("-t TEMPLATE", "--template=TEMPLATE", "Use specific template") do |template|
      @parsed_options["template"] = template
    end
  end

  def run(args : Array(String)) : Int32
    # Mock implementation
    return 1 if args.empty?
    @remaining_arguments = args
    0
  end
end

class TestNewCommand < AmberCLI::Core::BaseCommand
  def initialize
    super("new")
    setup_options
  end

  def setup_options
    @option_parser.banner = "Usage: amber new [app_name] [options]"
    @option_parser.on("-d DATABASE", "--database=DATABASE", "Database to use") do |db|
      @parsed_options["database"] = db
    end
    @option_parser.on("--api", "Generate API-only application") do
      @parsed_options["api"] = true
    end
  end

  def run(args : Array(String)) : Int32
    return 1 if args.empty?
    @remaining_arguments = args
    0
  end
end

describe AmberCLI::Core::BaseCommand do
  describe "#initialize" do
    it "sets up basic command structure" do
      command = TestGenerateCommand.new
      command.command_name.should eq("generate")
      command.option_parser.should_not be_nil
      command.parsed_options.should be_empty
      command.remaining_arguments.should be_empty
    end
  end

  describe "#parse_arguments" do
    context "with valid arguments" do
      it "parses simple flags correctly" do
        command = TestGenerateCommand.new
        args = ["model", "User", "--force", "--verbose"]
        
        remaining = command.parse_arguments(args)
        
        command.parsed_options["force"].should be_true
        command.parsed_options["verbose"].should be_true
        remaining.should eq(["model", "User"])
      end

      it "parses arguments with values" do
        command = TestGenerateCommand.new
        args = ["controller", "Users", "--template", "custom_controller", "--force"]
        
        remaining = command.parse_arguments(args)
        
        command.parsed_options["template"].should eq("custom_controller")
        command.parsed_options["force"].should be_true
        remaining.should eq(["controller", "Users"])
      end

      it "handles mixed short and long options" do
        command = TestGenerateCommand.new
        args = ["scaffold", "Post", "-f", "--template", "blog_scaffold", "-v"]
        
        remaining = command.parse_arguments(args)
        
        command.parsed_options["force"].should be_true
        command.parsed_options["verbose"].should be_true
        command.parsed_options["template"].should eq("blog_scaffold")
        remaining.should eq(["scaffold", "Post"])
      end

      it "preserves non-option arguments in order" do
        command = TestNewCommand.new
        args = ["my_app", "--database", "postgresql", "extra_arg"]
        
        remaining = command.parse_arguments(args)
        
        command.parsed_options["database"].should eq("postgresql")
        remaining.should eq(["my_app", "extra_arg"])
      end
    end

    context "with edge cases" do
      it "handles empty argument list" do
        command = TestGenerateCommand.new
        remaining = command.parse_arguments([] of String)
        
        command.parsed_options.should be_empty
        remaining.should be_empty
      end

      it "handles only flags with no arguments" do
        command = TestGenerateCommand.new
        args = ["--force", "--verbose"]
        
        remaining = command.parse_arguments(args)
        
        command.parsed_options["force"].should be_true
        command.parsed_options["verbose"].should be_true
        remaining.should be_empty
      end

      it "handles arguments without any flags" do
        command = TestGenerateCommand.new
        args = ["model", "User", "name:string", "email:string"]
        
        remaining = command.parse_arguments(args)
        
        command.parsed_options.should be_empty
        remaining.should eq(["model", "User", "name:string", "email:string"])
      end
    end

    context "error handling" do
      it "raises error for unknown options" do
        command = TestGenerateCommand.new
        args = ["model", "User", "--unknown-option"]
        
        expect_raises(Exception) do
          command.parse_arguments(args)
        end
      end
    end
  end

  describe "#has_option?" do
    it "returns true for set boolean options" do
      command = TestGenerateCommand.new
      command.parse_arguments(["--force"])
      
      command.has_option?("force").should be_true
      command.has_option?("verbose").should be_false
    end

    it "returns true for options with values" do
      command = TestGenerateCommand.new
      command.parse_arguments(["--template", "custom"])
      
      command.has_option?("template").should be_true
      command.has_option?("force").should be_false
    end
  end

  describe "#option_value" do
    it "returns string values correctly" do
      command = TestGenerateCommand.new
      command.parse_arguments(["--template", "api_controller"])
      
      command.option_value("template").should eq("api_controller")
    end

    it "returns boolean values correctly" do
      command = TestGenerateCommand.new
      command.parse_arguments(["--force"])
      
      command.option_value("force").should be_true
    end

    it "returns nil for unset options" do
      command = TestGenerateCommand.new
      command.parse_arguments([] of String)
      
      command.option_value("template").should be_nil
      command.option_value("force").should be_nil
    end
  end

  describe "#show_help" do
    it "displays the option parser help" do
      command = TestGenerateCommand.new
      
      # Capture output
      output = IO::Memory.new
      command.show_help(output)
      help_text = output.to_s
      
      help_text.should contain("Usage: amber generate")
      help_text.should contain("--force")
      help_text.should contain("--verbose")
      help_text.should contain("--template")
    end
  end
end

describe AmberCLI::Core::CommandRegistry do
  describe "#register_command" do
    it "registers a command successfully" do
      registry = AmberCLI::Core::CommandRegistry.new
      command = TestGenerateCommand.new
      
      registry.register_command(command)
      
      registry.has_command?("generate").should be_true
    end

    it "allows multiple command registrations" do
      registry = AmberCLI::Core::CommandRegistry.new
      generate_command = TestGenerateCommand.new
      new_command = TestNewCommand.new
      
      registry.register_command(generate_command)
      registry.register_command(new_command)
      
      registry.has_command?("generate").should be_true
      registry.has_command?("new").should be_true
    end

    it "overwrites existing command with same name" do
      registry = AmberCLI::Core::CommandRegistry.new
      command1 = TestGenerateCommand.new
      command2 = TestGenerateCommand.new
      
      registry.register_command(command1)
      registry.register_command(command2)
      
      # Should still have the command, but it's the newer instance
      registry.has_command?("generate").should be_true
    end
  end

  describe "#has_command?" do
    it "returns true for registered commands" do
      registry = AmberCLI::Core::CommandRegistry.new
      command = TestGenerateCommand.new
      
      registry.register_command(command)
      
      registry.has_command?("generate").should be_true
    end

    it "returns false for unregistered commands" do
      registry = AmberCLI::Core::CommandRegistry.new
      
      registry.has_command?("nonexistent").should be_false
    end

    it "is case sensitive" do
      registry = AmberCLI::Core::CommandRegistry.new
      command = TestGenerateCommand.new
      
      registry.register_command(command)
      
      registry.has_command?("generate").should be_true
      registry.has_command?("Generate").should be_false
      registry.has_command?("GENERATE").should be_false
    end
  end

  describe "#run_command" do
    context "with valid commands" do
      it "runs a command with no arguments" do
        registry = AmberCLI::Core::CommandRegistry.new
        command = TestGenerateCommand.new
        registry.register_command(command)
        
        result = registry.run_command("generate", ["model", "User"])
        
        result.should eq(0)
        command.remaining_arguments.should eq(["model", "User"])
      end

      it "runs a command with options" do
        registry = AmberCLI::Core::CommandRegistry.new
        command = TestGenerateCommand.new
        registry.register_command(command)
        
        result = registry.run_command("generate", ["model", "User", "--force"])
        
        result.should eq(0)
        command.has_option?("force").should be_true
        command.remaining_arguments.should eq(["model", "User"])
      end

      it "handles command that returns error status" do
        registry = AmberCLI::Core::CommandRegistry.new
        command = TestGenerateCommand.new
        registry.register_command(command)
        
        # Empty args should cause TestGenerateCommand to return 1
        result = registry.run_command("generate", [] of String)
        
        result.should eq(1)
      end
    end

    context "with invalid commands" do
      it "returns error code for unregistered command" do
        registry = AmberCLI::Core::CommandRegistry.new
        
        result = registry.run_command("nonexistent", ["some", "args"])
        
        result.should eq(1)
      end
    end

    context "error handling" do
      it "handles argument parsing errors gracefully" do
        registry = AmberCLI::Core::CommandRegistry.new
        command = TestGenerateCommand.new
        registry.register_command(command)
        
        # This should cause an error due to invalid option
        result = registry.run_command("generate", ["model", "User", "--invalid-option"])
        
        result.should eq(1)
      end
    end
  end

  describe "#list_commands" do
    it "returns empty array for no registered commands" do
      registry = AmberCLI::Core::CommandRegistry.new
      
      commands = registry.list_commands
      
      commands.should be_empty
    end

    it "returns list of registered command names" do
      registry = AmberCLI::Core::CommandRegistry.new
      generate_command = TestGenerateCommand.new
      new_command = TestNewCommand.new
      
      registry.register_command(generate_command)
      registry.register_command(new_command)
      
      commands = registry.list_commands
      
      commands.should contain("generate")
      commands.should contain("new")
      commands.size.should eq(2)
    end

    it "returns sorted command names" do
      registry = AmberCLI::Core::CommandRegistry.new
      
      # Register in reverse alphabetical order
      new_command = TestNewCommand.new
      generate_command = TestGenerateCommand.new
      
      registry.register_command(new_command)
      registry.register_command(generate_command)
      
      commands = registry.list_commands
      
      commands.should eq(["generate", "new"])
    end
  end
end 