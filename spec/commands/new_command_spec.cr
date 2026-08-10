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

    it "preserves database and ECR flags alongside --type" do
      command = AmberCLI::Commands::NewCommand.new("new")
      args = ["my_app", "-d", "sqlite", "-t", "ecr", "--type=web"]

      command.option_parser.unknown_args do |unknown_args, _|
        command.remaining_arguments.concat(unknown_args)
      end
      command.option_parser.parse(args)

      command.database.should eq("sqlite")
      command.template.should eq("ecr")
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

  describe "#execute" do
    it "creates the supported web template at an absolute path" do
      SpecHelper.within_temp_directory do |temp_dir|
        destination = File.join(temp_dir, "outside", "beta_smoke")
        command = AmberCLI::Commands::NewCommand.new("new")

        command.parse_and_execute([destination, "--type=web", "--no-deps", "-d", "sqlite"])

        File.exists?(File.join(destination, "src/beta_smoke.cr")).should be_true
        Dir.exists?(File.join(destination, "bin")).should be_true

        shard = File.read(File.join(destination, "shard.yml"))
        shard.should contain("github: amberframework/amber")
        shard.should contain("version: 2.0.0-beta.2")
        shard.should_not contain("crimson-knight")
        shard.should_not contain("grant:")
        shard.should_not contain("slang")

        config = YAML.parse(File.read(File.join(destination, "config/environments/development.yml")))
        config["server"]["port"].as_i.should eq(3000)
        config["database"]["url"].as_s.should contain("sqlite3:")

        routes = File.read(File.join(destination, "config/routes.cr"))
        routes.should contain("pipeline :static")
        routes.should contain("Amber::Pipe::Static.new")
        routes.should contain(%(get "/*", Amber::Controller::Static, :index))

        index = File.read(File.join(destination, "src/views/home/index.ecr"))
        index.should contain("Your new idea")
        index.should contain("Amber V2 · Web application")
        index.should contain("Ready to customize")
        index.should contain("amber generate controller Posts")
        index.should_not contain("class=\"welcome\"")

        stylesheet = File.read(File.join(destination, "public/css/app.css"))
        stylesheet.should contain("--amber-accent: #e96918")
        stylesheet.should contain(".starter-main")
        stylesheet.should contain(".starter-crystal")

        File.exists?(File.join(destination, "src/views/home/index.ecr")).should be_true
        File.exists?(File.join(destination, "src/views/home/index.slang")).should be_false
      end
    end
  end
end
