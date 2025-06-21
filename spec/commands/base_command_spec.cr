require "../amber_cli_spec"

# Test command implementations for spec purposes
class TestGenerateCommand < AmberCLI::Core::BaseCommand
  def help_description : String
    "Test generate command for specs"
  end

  def setup_command_options
    option_parser.banner = "Usage: amber generate [generator] [name] [options]"
    option_parser.on("-f", "--force", "Force overwrite existing files") do
      @parsed_options["force"] = true
    end
    option_parser.on("-v", "--verbose", "Verbose output") do
      @parsed_options["verbose"] = true
    end
    option_parser.on("-t TEMPLATE", "--template=TEMPLATE", "Use specific template") do |template|
      @parsed_options["template"] = template
    end
  end

  def execute
    # Mock implementation
    if remaining_arguments.empty?
      exit!(error: true)
    end
  end
end

class TestNewCommand < AmberCLI::Core::BaseCommand
  def help_description : String
    "Test new command for specs"
  end

  def setup_command_options
    option_parser.banner = "Usage: amber new [app_name] [options]"
    option_parser.on("-d DATABASE", "--database=DATABASE", "Database to use") do |db|
      @parsed_options["database"] = db
    end
    option_parser.on("--api", "Generate API-only application") do
      @parsed_options["api"] = true
    end
  end

  def execute
    if remaining_arguments.empty?
      exit!(error: true)
    end
  end
end

describe AmberCLI::Core::BaseCommand do
  describe "#initialize" do
    it "sets up basic command structure" do
      command = TestGenerateCommand.new("generate")
      command.option_parser.should_not be_nil
      command.parsed_options.should be_empty
      command.remaining_arguments.should be_empty
    end
  end

  describe "#parse_and_execute" do
    context "with valid arguments" do
      it "parses simple flags correctly" do
        command = TestGenerateCommand.new("generate")
        args = ["model", "User", "--force", "--verbose"]
        
        # Mock parse_and_execute to not actually execute
        command.option_parser.unknown_args do |unknown_args, _|
          command.remaining_arguments.concat(unknown_args)
        end
        command.option_parser.parse(args)
        
        command.parsed_options["force"].should be_true
        command.parsed_options["verbose"].should be_true
        command.remaining_arguments.should eq(["model", "User"])
      end

      it "parses arguments with values" do
        command = TestGenerateCommand.new("generate")
        args = ["controller", "Users", "--template", "custom_controller", "--force"]
        
        command.option_parser.unknown_args do |unknown_args, _|
          command.remaining_arguments.concat(unknown_args)
        end
        command.option_parser.parse(args)
        
        command.parsed_options["template"].should eq("custom_controller")
        command.parsed_options["force"].should be_true
        command.remaining_arguments.should eq(["controller", "Users"])
      end

      it "handles mixed short and long options" do
        command = TestGenerateCommand.new("generate")
        args = ["scaffold", "Post", "-f", "--template", "blog_scaffold", "-v"]
        
        command.option_parser.unknown_args do |unknown_args, _|
          command.remaining_arguments.concat(unknown_args)
        end
        command.option_parser.parse(args)
        
        command.parsed_options["force"].should be_true
        command.parsed_options["verbose"].should be_true
        command.parsed_options["template"].should eq("blog_scaffold")
        command.remaining_arguments.should eq(["scaffold", "Post"])
      end

      it "preserves non-option arguments in order" do
        command = TestNewCommand.new("new")
        args = ["my_app", "--database", "postgresql", "extra_arg"]
        
        command.option_parser.unknown_args do |unknown_args, _|
          command.remaining_arguments.concat(unknown_args)
        end
        command.option_parser.parse(args)
        
        command.parsed_options["database"].should eq("postgresql")
        command.remaining_arguments.should eq(["my_app", "extra_arg"])
      end
    end

    context "with edge cases" do
      it "handles empty argument list" do
        command = TestGenerateCommand.new("generate")
        
        command.option_parser.unknown_args do |unknown_args, _|
          command.remaining_arguments.concat(unknown_args)
        end
        command.option_parser.parse([] of String)
        
        command.parsed_options.should be_empty
        command.remaining_arguments.should be_empty
      end

      it "handles only flags with no arguments" do
        command = TestGenerateCommand.new("generate")
        args = ["--force", "--verbose"]
        
        command.option_parser.unknown_args do |unknown_args, _|
          command.remaining_arguments.concat(unknown_args)
        end
        command.option_parser.parse(args)
        
        command.parsed_options["force"].should be_true
        command.parsed_options["verbose"].should be_true
        command.remaining_arguments.should be_empty
      end

      it "handles arguments without any flags" do
        command = TestGenerateCommand.new("generate")
        args = ["model", "User", "name:string", "email:string"]
        
        command.option_parser.unknown_args do |unknown_args, _|
          command.remaining_arguments.concat(unknown_args)
        end
        command.option_parser.parse(args)
        
        command.parsed_options.should be_empty
        command.remaining_arguments.should eq(["model", "User", "name:string", "email:string"])
      end
    end
  end

  describe "option access methods" do
    it "provides access to parsed options" do
      command = TestGenerateCommand.new("generate")
      
      command.option_parser.unknown_args do |unknown_args, _|
        command.remaining_arguments.concat(unknown_args)
      end
      command.option_parser.parse(["--force", "--template", "custom"])
      
      command.parsed_options["force"].should be_true
      command.parsed_options["template"].should eq("custom")
    end
  end

  describe "#help_description" do
    it "returns the command description" do
      command = TestGenerateCommand.new("generate")
      command.help_description.should eq("Test generate command for specs")
    end
  end
end

describe AmberCLI::Core::CommandRegistry do
  describe ".register" do
    it "registers a command class successfully" do
      AmberCLI::Core::CommandRegistry.register("test_generate", ["tg"], TestGenerateCommand)
      
      AmberCLI::Core::CommandRegistry.find_command("test_generate").should eq(TestGenerateCommand)
      AmberCLI::Core::CommandRegistry.find_command("tg").should eq(TestGenerateCommand)
    end

    it "allows multiple command registrations" do
      AmberCLI::Core::CommandRegistry.register("test_generate2", ["tg2"], TestGenerateCommand)
      AmberCLI::Core::CommandRegistry.register("test_new2", ["tn2"], TestNewCommand)
      
      AmberCLI::Core::CommandRegistry.find_command("test_generate2").should eq(TestGenerateCommand)
      AmberCLI::Core::CommandRegistry.find_command("test_new2").should eq(TestNewCommand)
    end
  end

  describe ".find_command" do
    it "returns command class for registered commands" do
      AmberCLI::Core::CommandRegistry.register("test_find", ["tf"], TestGenerateCommand)
      
      AmberCLI::Core::CommandRegistry.find_command("test_find").should eq(TestGenerateCommand)
    end

    it "returns nil for unregistered commands" do
      AmberCLI::Core::CommandRegistry.find_command("nonexistent").should be_nil
    end

    it "works with aliases" do
      AmberCLI::Core::CommandRegistry.register("test_alias", ["ta", "talias"], TestGenerateCommand)
      
      AmberCLI::Core::CommandRegistry.find_command("test_alias").should eq(TestGenerateCommand)
      AmberCLI::Core::CommandRegistry.find_command("ta").should eq(TestGenerateCommand)
      AmberCLI::Core::CommandRegistry.find_command("talias").should eq(TestGenerateCommand)
    end
  end

  describe ".list_commands" do
    it "returns list of registered command names" do
      # Clear any existing commands for this test
      AmberCLI::Core::CommandRegistry.register("test_list1", ["tl1"], TestGenerateCommand)
      AmberCLI::Core::CommandRegistry.register("test_list2", ["tl2"], TestNewCommand)
      
      commands = AmberCLI::Core::CommandRegistry.list_commands
      
      commands.should contain("test_list1")
      commands.should contain("test_list2")
      commands.should contain("tl1")
      commands.should contain("tl2")
    end
  end
end 