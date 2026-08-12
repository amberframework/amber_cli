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
        shard.should contain("version: 2.0.0-beta.4")
        shard.should contain("grant:")
        shard.should contain("github: crimson-knight/grant")
        shard.should contain("asset_pipeline:")
        shard.should contain("github: amberframework/asset_pipeline")
        shard.should contain("github: crystal-lang/crystal-sqlite3")
        shard.should_not contain("slang")

        amber_config = YAML.parse(File.read(File.join(destination, ".amber.yml")))
        amber_config["database"].as_s.should eq("sqlite")
        amber_config["model"].as_s.should eq("grant")

        database_config = File.read(File.join(destination, "config/database.cr"))
        database_config.should contain(%(require "grant/adapter/sqlite"))
        database_config.should contain(%(name: "primary"))
        database_config.should contain(%(ENV["DATABASE_URL"]? || Amber.settings.database_url))

        application_config = File.read(File.join(destination, "config/application.cr"))
        application_config.should contain(%(require "./assets"))
        assets_config = File.read(File.join(destination, "config/assets.cr"))
        assets_config.should eq(%(Amber::Assets.configure(manifest_path: "public/assets/manifest.json")\n))
        assets_config.should_not contain("AssetPipeline::StaticAssets::Compiler")

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

        stylesheet = File.read(File.join(destination, "app/assets/stylesheets/app.css"))
        stylesheet.should contain("--amber-accent: #e96918")
        stylesheet.should contain(".starter-main")
        stylesheet.should contain(".starter-crystal")
        stylesheet.should contain(%(url("../images/amber-crystal.svg")))

        layout = File.read(File.join(destination, "src/views/layouts/application.ecr"))
        layout.should contain(%(favicon_tag("images/favicon.svg")))
        layout.should contain(%(stylesheet_link_tag("stylesheets/app.css")))
        layout.should contain("javascript_importmap_tag({\"app\" => \"javascript/app.js\"}")
        layout.should contain(%(type="module">import "app";))
        layout.should_not contain(%(<script src="/js/app.js">))

        javascript = File.read(File.join(destination, "app/assets/javascript/app.js"))
        javascript.should contain(%(document.documentElement.dataset.javascript = "ready"))

        File.exists?(File.join(destination, "app/assets/images/amber-crystal.svg")).should be_true
        File.exists?(File.join(destination, "app/assets/images/favicon.svg")).should be_true
        Dir.exists?(File.join(destination, "app/assets/fonts")).should be_true
        Dir.exists?(File.join(destination, "app/assets/files")).should be_true
        File.exists?(File.join(destination, "app/assets/fonts/.gitkeep")).should be_true
        File.exists?(File.join(destination, "app/assets/files/.gitkeep")).should be_true
        File.exists?(File.join(destination, "public/css/app.css")).should be_false
        File.exists?(File.join(destination, "public/js/app.js")).should be_false
        File.exists?(File.join(destination, "public/favicon.ico")).should be_false

        manifest_path = File.join(destination, "public/assets/manifest.json")
        File.exists?(manifest_path).should be_true
        manifest = JSON.parse(File.read(manifest_path))
        manifest["schema_version"].as_i.should eq(1)
        assets = manifest["assets"].as_h
        assets.keys.sort.should eq([
          "images/amber-crystal.svg",
          "images/favicon.svg",
          "javascript/app.js",
          "stylesheets/app.css",
        ])
        css_url = assets["stylesheets/app.css"]["path"].as_s
        logo_url = assets["images/amber-crystal.svg"]["path"].as_s
        assets["stylesheets/app.css"]["integrity"].as_s.should start_with("sha256-")
        compiled_stylesheet = File.read(File.join(destination, "public", css_url.lchop('/')))
        compiled_stylesheet.should contain(logo_url)

        gitignore = File.read(File.join(destination, ".gitignore"))
        gitignore.should contain("/public/assets/")

        File.exists?(File.join(destination, "src/views/home/index.ecr")).should be_true
        File.exists?(File.join(destination, "src/views/home/index.slang")).should be_false

        readme = File.read(File.join(destination, "README.md"))
        readme.should contain("amber generate scaffold Pet")
        readme.should contain("amber database migrate")
        readme.should contain("amber assets build")
        readme.should contain("app/assets/stylesheets/")
        readme.should contain("public/assets/manifest.json")
      end
    end
  end
end
