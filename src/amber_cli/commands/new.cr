require "../core/base_command"

module AmberCLI::Commands
  class NewCommand < AmberCLI::Core::BaseCommand
    getter database : String = "pg"
    getter template : String = "slang"
    getter recipe : String?
    getter assume_yes : Bool = false
    getter no_deps : Bool = false
    getter name : String = ""

    def help_description : String
      "Generates a new Amber project"
    end

    def setup_command_options
      option_parser.on("-d DATABASE", "--database=DATABASE", "Select the database engine (pg, mysql, sqlite)") do |db|
        @parsed_options["database"] = db
        @database = db
      end

      option_parser.on("-t TEMPLATE", "--template=TEMPLATE", "Select template engine (slang, ecr)") do |tmpl|
        @parsed_options["template"] = tmpl
        @template = tmpl
      end

      option_parser.on("-r RECIPE", "--recipe=RECIPE", "Use a named recipe") do |recipe|
        @parsed_options["recipe"] = recipe
        @recipe = recipe
      end

      option_parser.on("-y", "--assume-yes", "Assume yes to disable interactive mode") do
        @parsed_options["assume_yes"] = true
        @assume_yes = true
      end

      option_parser.on("--no-deps", "Don't install dependencies") do
        @parsed_options["no_deps"] = true
        @no_deps = true
      end

      option_parser.separator ""
      option_parser.separator "Usage: amber new [NAME] [options]"
      option_parser.separator ""
      option_parser.separator "Examples:"
      option_parser.separator "  amber new my_app"
      option_parser.separator "  amber new my_app -d mysql -t ecr"
      option_parser.separator "  amber new . -d sqlite"
    end

    def validate_arguments
      if remaining_arguments.empty?
        error "Project name is required"
        puts option_parser
        exit(1)
      end
      @name = remaining_arguments[0]
    end

    def execute
      if name == "."
        project_name = File.basename(Dir.current)
        full_path_name = Dir.current
      else
        project_name = File.basename(name)
        full_path_name = File.join(Dir.current, name)
      end

      if full_path_name =~ /\s+/
        error "Path and project name can't contain a space."
        info "Replace spaces with underscores or dashes."
        info "#{full_path_name} should be #{full_path_name.gsub(/\s+/, "_")}"
        exit!(error: true)
      end

      info "Creating new Amber application: #{project_name}"
      info "Database: #{database}"
      info "Template: #{template}"
      info "Location: #{full_path_name}"

      # TODO: Implement the actual project generation using the new generator system
      # For now, just create a basic directory structure
      create_project_structure(full_path_name, project_name)

      # Encrypt production.yml by default
      if File.exists?(File.join(full_path_name, "config", "environments", "production.yml"))
        cwd = Dir.current
        Dir.cd(full_path_name)
        # TODO: Call encrypt command when it's updated
        # AmberCLI::Core::CommandRegistry.execute_command("encrypt", ["production", "--noedit"])
        Dir.cd(cwd)
      end

      success "Successfully created #{project_name}!"
      info "To get started:"
      info "  cd #{name}" unless name == "."
      info "  shards install" unless no_deps
      info "  amber watch"
    end

    private def create_project_structure(path : String, name : String)
      # Create basic directory structure
      dirs = [
        "config", "config/environments", "config/initializers",
        "db", "db/migrations", "public", "public/css", "public/js", "public/img",
        "spec", "src", "src/controllers", "src/models", "src/views", "src/views/layouts",
      ]

      dirs.each do |dir|
        full_dir = File.join(path, dir)
        Dir.mkdir_p(full_dir) unless Dir.exists?(full_dir)
      end

      # Create basic files
      create_shard_yml(path, name)
      create_amber_yml(path, name)
      create_main_file(path, name)
      create_config_files(path, name)

      info "Created project structure"
    end

    private def create_shard_yml(path : String, name : String)
      shard_content = <<-SHARD
        name: #{name}
        version: 0.1.0

        authors:
          - Your Name <your.email@example.com>

        crystal: ">= 1.0.0, < 2.0"

        license: MIT

        targets:
          #{name}:
            main: src/#{name}.cr

        dependencies:
          amber:
            github: amberframework/amber
            version: ~> 1.0
        SHARD

      File.write(File.join(path, "shard.yml"), shard_content)
    end

    private def create_amber_yml(path : String, name : String)
      amber_content = <<-AMBER
        app: #{name}
        author: Your Name
        email: your.email@example.com
        database: #{database}
        language: crystal
        model: granite
        recipe_source: amberframework/recipes
        template: #{template}
        AMBER

      File.write(File.join(path, ".amber.yml"), amber_content)
    end

    private def create_main_file(path : String, name : String)
      main_content = <<-MAIN
        require "./config/*"
        require "./src/#{name}/*"

        Amber::Server.configure do |settings|
          settings.name = "#{name}"
          settings.secret_key_base = ENV["SECRET_KEY_BASE"]? || "#{Random::Secure.hex(64)}"
        end

        Amber::Server.start
        MAIN

      File.write(File.join(path, "src/#{name}.cr"), main_content)
    end

    private def create_config_files(path : String, name : String)
      # Create basic config/application.cr
      app_config = <<-CONFIG
        require "amber"
        require "../src/controllers/application_controller"

        Amber::Server.configure do |settings|
          settings.name = "#{name}"
          settings.port = ENV["PORT"]?.try(&.to_i) || 3000
          settings.env = ENV["AMBER_ENV"]? || "development"
          settings.secret_key_base = ENV["SECRET_KEY_BASE"]? || "change_me"
        end
        CONFIG

      File.write(File.join(path, "config/application.cr"), app_config)

      # Create basic controller
      controller_content = <<-CONTROLLER
        class ApplicationController < Amber::Controller::Base
        end
        CONTROLLER

      File.write(File.join(path, "src/controllers/application_controller.cr"), controller_content)
    end
  end
end

# Register the command
AmberCLI::Core::CommandRegistry.register("new", ["n"], AmberCLI::Commands::NewCommand)
