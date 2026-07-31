require "../core/base_command"
require "../generators/native_app"

# The `new` command creates a new Amber V2 application with a complete directory
# structure, configuration files, and a working home page.
#
# ## Usage
# ```
# amber new [app_name] -d [pg | mysql | sqlite] -t ecr --type [web | native] --no-deps
# ```
#
# ## Options
# - `-d, --database` - Database type (pg, mysql, sqlite)
# - `-t, --template` - Template language (ECR is the only V2 engine)
# - `--type` - Application type: web (default) or native (cross-platform desktop/mobile)
# - `--no-deps` - Skip dependency installation
#
# ## Examples
# ```
# # Create a new web app with PostgreSQL and ECR (defaults)
# amber new my_blog
#
# # Record MySQL as the database for future persistence tooling
# amber new my_blog -d mysql
#
# # Create a native cross-platform app (macOS, iOS, Android)
# amber new my_native_app --type native
#
# # Create app with SQLite (for development)
# amber new quick_app -d sqlite
# ```
module AmberCLI::Commands
  class NewCommand < AmberCLI::Core::BaseCommand
    VALID_APP_TYPES = %w[web native]
    VALID_DATABASES = %w[pg mysql sqlite]
    VALID_TEMPLATES = %w[ecr]

    getter database : String = "pg"
    getter template : String = "ecr"
    getter app_type : String = "web"
    getter assume_yes : Bool = false
    getter no_deps : Bool = false
    getter name : String = ""

    def help_description : String
      "Generates a new Amber V2 project"
    end

    def setup_command_options
      option_parser.on("-d DATABASE", "--database=DATABASE", "Select the database engine (pg, mysql, sqlite)") do |db|
        unless VALID_DATABASES.includes?(db)
          error "Invalid database '#{db}'. Valid databases: #{VALID_DATABASES.join(", ")}"
          exit(1)
        end
        @parsed_options["database"] = db
        @database = db
      end

      option_parser.on("-t TEMPLATE", "--template=TEMPLATE", "Template engine (ecr; the only V2 engine)") do |tmpl|
        unless VALID_TEMPLATES.includes?(tmpl)
          error "Invalid template '#{tmpl}'. Amber V2 supports ECR only."
          exit(1)
        end
        @parsed_options["template"] = tmpl
        @template = tmpl
      end

      option_parser.on("--type=TYPE", "Application type: web (default), native (cross-platform)") do |type|
        unless VALID_APP_TYPES.includes?(type)
          error "Invalid app type '#{type}'. Valid types: #{VALID_APP_TYPES.join(", ")}"
          exit(1)
        end
        @parsed_options["app_type"] = type
        @app_type = type
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
      option_parser.separator "App types:"
      option_parser.separator "  web     Web application with HTTP server, routes, views (default)"
      option_parser.separator "  native  Preview: cross-platform native app (macOS, iOS, Android)"
      option_parser.separator "          Uses Asset Pipeline UI, FSDD process managers,"
      option_parser.separator "          crystal-audio, and platform build scripts."
      option_parser.separator ""
      option_parser.separator "Examples:"
      option_parser.separator "  amber new my_app"
      option_parser.separator "  amber new my_app -d mysql -t ecr"
      option_parser.separator "  amber new my_native_app --type native"
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
        full_path_name = File.expand_path(name, Dir.current)
      end

      if full_path_name =~ /\s+/
        error "Path and project name can't contain a space."
        info "Replace spaces with underscores or dashes."
        info "#{full_path_name} should be #{full_path_name.gsub(/\s+/, "_")}"
        exit!(error: true)
      end

      if app_type == "native"
        execute_native(full_path_name, project_name)
      else
        execute_web(full_path_name, project_name)
      end
    end

    private def execute_native(full_path_name : String, project_name : String)
      info "Creating new Amber V2 native application: #{project_name}"
      warning "Native application generation is a preview surface in this beta."
      info "Type: native (cross-platform: macOS, iOS, Android)"
      info "Location: #{full_path_name}"

      generator = AmberCLI::Generators::NativeApp.new(full_path_name, project_name)
      generator.generate

      info "Created native project structure"
      info "Native manifest: config/native.yml"
      info "Generator-owned Apple shell files: mobile/apple/generated/"

      success "Successfully created #{project_name}!"
      puts ""
      info "To get started:"
      info "  cd #{name}" unless name == "."
      info "  make setup          # Install shards + create symlinks"
      info "  make macos          # Build for macOS"
      info "  make run            # Build and run"
      info "  make spec           # Run Crystal specs"
      puts ""
      info "Cross-platform builds:"
      info "  ./mobile/ios/build_crystal_lib.sh simulator    # iOS"
      info "  ./mobile/android/build_crystal_lib.sh          # Android"
      puts ""
      info "Test suite:"
      info "  ./mobile/run_all_tests.sh          # L1 + L2 tests"
      info "  ./mobile/run_all_tests.sh --e2e    # Full E2E tests"
    end

    private def execute_web(full_path_name : String, project_name : String)
      info "Creating new Amber V2 application: #{project_name}"
      info "Database: #{database}"
      info "Template: #{template}"
      info "Location: #{full_path_name}"

      create_project_structure(full_path_name, project_name)

      install_dependencies(full_path_name) unless no_deps

      # Encrypt production.yml by default
      if File.exists?(File.join(full_path_name, "config", "environments", "production.yml"))
        cwd = Dir.current
        Dir.cd(full_path_name)
        # TODO: Call encrypt command when it's updated
        # AmberCLI::Core::CommandRegistry.execute_command("encrypt", ["production", "--noedit"])
        Dir.cd(cwd)
      end

      success "Successfully created #{project_name}!"
      puts ""
      info "To get started:"
      info "  cd #{name}" unless name == "."
      info "  shards install" if no_deps
      info "  crystal spec"
      info "  amber watch"
      puts ""
      info "Persistence, auth, API-resource, and native generators are preview surfaces."
      info "The generated web app intentionally has no ORM or database driver."
    end

    private def install_dependencies(path : String)
      info "Installing dependencies..."
      status = Process.run(
        "shards",
        ["install"],
        chdir: path,
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )
      return if status.success?

      warning "Dependency installation failed; the project files were kept."
      warning "Run 'shards install' in #{path} after resolving the error."
      exit!(error: true)
    rescue ex : File::NotFoundError
      warning "The 'shards' executable was not found; the project files were kept."
      warning "Install Crystal and run 'shards install' in #{path}."
      exit!(error: true)
    end

    private def create_project_structure(path : String, name : String)
      # Create V2 directory structure
      dirs = [
        # Config
        "config", "config/environments", "config/initializers",
        # Database
        "db", "db/migrations",
        # Build output and public assets
        "bin", "public", "public/css", "public/js", "public/img",
        # Spec directories
        "spec", "spec/controllers", "spec/models", "spec/schemas",
        "spec/jobs", "spec/mailers", "spec/channels", "spec/requests",
        # Source directories
        "src", "src/controllers", "src/models",
        "src/views", "src/views/layouts", "src/views/home",
        "src/schemas", "src/jobs", "src/mailers", "src/channels", "src/sockets",
      ]

      dirs.each do |dir|
        full_dir = File.join(path, dir)
        Dir.mkdir_p(full_dir) unless Dir.exists?(full_dir)
      end

      # Create all project files
      create_shard_yml(path, name)
      create_amber_yml(path, name)
      create_gitignore(path)
      create_main_file(path, name)
      create_config_files(path, name)
      create_routes_file(path, name)
      create_environment_files(path, name)
      create_home_controller(path, name)
      create_application_controller(path)
      create_views(path, name)
      create_spec_helper(path, name)
      create_home_controller_spec(path)
      create_seeds_file(path)
      create_keep_files(path)
      create_public_files(path)

      info "Created project structure"
    end

    private def create_shard_yml(path : String, name : String)
      shard_content = <<-SHARD
name: #{name}
version: 0.1.0

authors:
  - Your Name <your.email@example.com>

crystal: ">= 1.20.0, < 2.0"

license: UNLICENSED

targets:
  #{name}:
    main: src/#{name}.cr

dependencies:
  amber:
    github: amberframework/amber
    version: 2.0.0-beta.2
SHARD

      write_text(File.join(path, "shard.yml"), shard_content)
    end

    private def create_amber_yml(path : String, name : String)
      amber_content = <<-AMBER
app: #{name}
type: web
author: Your Name
email: your.email@example.com
database: #{database}
language: crystal
model: none
template: ecr
AMBER

      write_text(File.join(path, ".amber.yml"), amber_content)
    end

    private def create_gitignore(path : String)
      gitignore_content = <<-GITIGNORE
# Crystal
/docs/
/lib/
/bin/
/.shards/
*.dwarf

# OS files
.DS_Store
Thumbs.db

# Editor files
*.swp
*.swo
*~
.idea/
.vscode/

# Local secrets
.env
/config/environments/*.local.yml

# Dependencies
/node_modules/

# Build artifacts
/tmp/
GITIGNORE

      write_text(File.join(path, ".gitignore"), gitignore_content)
    end

    private def create_main_file(path : String, name : String)
      main_content = <<-MAIN
require "../config/*"
require "./controllers/**"
require "./models/**"
require "./schemas/**"
require "./jobs/**"
require "./mailers/**"
require "./channels/**"

Amber::Server.start
MAIN

      write_text(File.join(path, "src/#{name}.cr"), main_content)
    end

    private def create_config_files(path : String, name : String)
      app_config = <<-CONFIG
require "amber"
CONFIG

      write_text(File.join(path, "config/application.cr"), app_config)
    end

    private def create_application_controller(path : String)
      controller_content = <<-CONTROLLER
class ApplicationController < Amber::Controller::Base
  LAYOUT = "application.#{template}"

  # Add shared before_action filters, helpers, etc.
  # All controllers inherit from this class.
end
CONTROLLER

      write_text(File.join(path, "src/controllers/application_controller.cr"), controller_content)
    end

    private def create_routes_file(path : String, name : String)
      routes_content = <<-ROUTES
Amber::Server.configure do
  pipeline :web do
    plug Amber::Pipe::Error.new
    plug Amber::Pipe::Logger.new
    plug Amber::Pipe::Session.new
    plug Amber::Pipe::Flash.new
    plug Amber::Pipe::CSRF.new
  end

  pipeline :static do
    plug Amber::Pipe::Error.new
    plug Amber::Pipe::Static.new("./public")
  end

  pipeline :api do
    plug Amber::Pipe::Error.new
    plug Amber::Pipe::Logger.new
  end

  routes :web do
    get "/", HomeController, :index
  end

  routes :static do
    get "/*", Amber::Controller::Static, :index
  end

  # routes :api do
  # end
end
ROUTES

      write_text(File.join(path, "config/routes.cr"), routes_content)
    end

    private def create_environment_files(path : String, name : String)
      database_urls = case database
                      when "mysql"
                        {"mysql://localhost:3306/#{name}_development", "mysql://localhost:3306/#{name}_test"}
                      when "sqlite"
                        {"sqlite3:./db/#{name}_development.db", "sqlite3:./db/#{name}_test.db"}
                      else
                        {"postgres://localhost:5432/#{name}_development", "postgres://localhost:5432/#{name}_test"}
                      end

      dev_config = environment_config(name, database_urls[0], "debug")
      test_config = environment_config(name, database_urls[1], "warn")
      prod_config = environment_config(name, "", "info", host: "0.0.0.0", secret: "")

      write_text(File.join(path, "config/environments/development.yml"), dev_config)
      write_text(File.join(path, "config/environments/test.yml"), test_config)
      write_text(File.join(path, "config/environments/production.yml"), prod_config)
    end

    private def environment_config(name : String, database_url : String, severity : String,
                                   host : String = "127.0.0.1",
                                   secret : String = Random::Secure.hex(32)) : String
      <<-YML
name: #{name}

server:
  host: #{host}
  port: 3000
  secret_key_base: "#{secret}"

database:
  url: "#{database_url}"

session:
  key: "#{name}.session"
  store: "signed_cookie"
  adapter: "memory"
  expires: 0

logging:
  severity: "#{severity}"
  colorize: true
YML
    end

    private def create_home_controller(path : String, name : String)
      home_controller = <<-CONTROLLER
class HomeController < ApplicationController
  def index
    render("index.#{template}")
  end
end
CONTROLLER

      write_text(File.join(path, "src/controllers/home_controller.cr"), home_controller)
    end

    private def create_views(path : String, name : String)
      layout_content = <<-LAYOUT
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>#{name}</title>
  <link rel="stylesheet" href="/css/app.css">
</head>
<body>
  <%= content %>
  <script src="/js/app.js"></script>
</body>
</html>
LAYOUT
      write_text(File.join(path, "src/views/layouts/application.ecr"), layout_content)

      index_content = <<-VIEW
<div class="welcome">
  <h1>Welcome to <%= Amber.settings.name %>!</h1>
  <p>Your Amber V2 application is running successfully.</p>

  <h2>Getting Started</h2>
  <ul>
    <li>Edit this page: <code>src/views/home/index.ecr</code></li>
    <li>Add routes: <code>config/routes.cr</code></li>
    <li>Add a controller: <code>amber generate controller Posts</code></li>
  </ul>
</div>
VIEW
      write_text(File.join(path, "src/views/home/index.ecr"), index_content)
    end

    private def create_spec_helper(path : String, name : String)
      spec_helper = <<-SPEC
require "spec"
require "../config/*"
require "../src/controllers/**"
require "../src/models/**"
require "../src/schemas/**"
require "../src/jobs/**"
require "../src/mailers/**"
require "../src/channels/**"

# Amber Testing Framework
require "amber/testing/testing"

# Include test helpers globally
include Amber::Testing::RequestHelpers
include Amber::Testing::Assertions
SPEC

      write_text(File.join(path, "spec/spec_helper.cr"), spec_helper)
    end

    private def create_home_controller_spec(path : String)
      spec_content = <<-SPEC
require "../spec_helper"

describe HomeController do
  describe "GET /" do
    it "responds successfully" do
      response = get("/")
      assert_response_success(response)
    end
  end
end
SPEC

      write_text(File.join(path, "spec/controllers/home_controller_spec.cr"), spec_content)
    end

    private def create_seeds_file(path : String)
      seeds_content = <<-SEEDS
# Database seed file
#
# Use this file to populate your database with initial data.
#
# Example:
#   User.create(name: "Admin", email: "admin@example.com")
#
# Run seeds with:
#   amber database seed

puts "Seeding database..."

# Add your seed data here

puts "Done!"
SEEDS

      write_text(File.join(path, "db/seeds.cr"), seeds_content)
    end

    private def create_keep_files(path : String)
      keep_dirs = [
        "config/initializers",
        "spec/models", "spec/schemas", "spec/jobs",
        "spec/mailers", "spec/channels", "spec/requests",
        "src/models", "src/schemas", "src/jobs",
        "src/mailers", "src/channels", "src/sockets",
      ]

      keep_dirs.each do |dir|
        keep_file = File.join(path, dir, ".keep")
        File.write(keep_file, "") unless File.exists?(keep_file)
      end
    end

    private def create_public_files(path : String)
      # CSS
      css_content = <<-CSS
/* Application styles */

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
    "Helvetica Neue", Arial, sans-serif;
  line-height: 1.6;
  color: #333;
  max-width: 960px;
  margin: 0 auto;
  padding: 20px;
}

.welcome {
  text-align: center;
  padding: 60px 20px;
}

.welcome h1 {
  font-size: 2.5em;
  margin-bottom: 0.5em;
}

.welcome code {
  background: #f4f4f4;
  padding: 2px 6px;
  border-radius: 3px;
  font-size: 0.9em;
}

.form-group {
  margin-bottom: 1em;
}

.form-group label {
  display: block;
  margin-bottom: 0.25em;
  font-weight: bold;
}

.form-group input,
.form-group textarea,
.form-group select {
  width: 100%;
  padding: 0.5em;
  border: 1px solid #ccc;
  border-radius: 3px;
  box-sizing: border-box;
}

table {
  width: 100%;
  border-collapse: collapse;
  margin: 1em 0;
}

th, td {
  padding: 0.75em;
  text-align: left;
  border-bottom: 1px solid #ddd;
}

th {
  background: #f4f4f4;
  font-weight: bold;
}

.flash {
  padding: 1em;
  margin-bottom: 1em;
  border-radius: 4px;
}

.flash-success {
  background: #d4edda;
  color: #155724;
  border: 1px solid #c3e6cb;
}

.flash-danger {
  background: #f8d7da;
  color: #721c24;
  border: 1px solid #f5c6cb;
}

.flash-info {
  background: #d1ecf1;
  color: #0c5460;
  border: 1px solid #bee5eb;
}
CSS

      write_text(File.join(path, "public/css/app.css"), css_content)

      # JavaScript
      js_content = <<-JS
// Application JavaScript
console.log("Amber V2 application loaded");
JS

      write_text(File.join(path, "public/js/app.js"), js_content)

      # robots.txt
      robots_content = <<-ROBOTS
User-agent: *
Disallow:
ROBOTS

      write_text(File.join(path, "public/robots.txt"), robots_content)

      # Placeholder favicon
      File.write(File.join(path, "public/favicon.ico"), "")

      # .keep for img
      File.write(File.join(path, "public/img/.keep"), "")
    end

    private def write_text(path : String, content : String)
      File.write(path, content.ends_with?("\n") ? content : "#{content}\n")
    end
  end
end

# Register the command
AmberCLI::Core::CommandRegistry.register("new", ["n"], AmberCLI::Commands::NewCommand)
