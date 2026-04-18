require "../core/base_command"
require "../generators/native_app"

# The `new` command creates a new Amber V2 application with a complete directory
# structure, configuration files, and a working home page.
#
# ## Usage
# ```
# amber new [app_name] -d [pg | mysql | sqlite] -t [ecr | slang] --type [web | native] --no-deps
# ```
#
# ## Options
# - `-d, --database` - Database type (pg, mysql, sqlite)
# - `-t, --template` - Template language (ecr, slang)
# - `--type` - Application type: web (default) or native (cross-platform desktop/mobile)
# - `--no-deps` - Skip dependency installation
#
# ## Examples
# ```
# # Create a new web app with PostgreSQL and ECR (defaults)
# amber new my_blog
#
# # Create app with MySQL and Slang templates
# amber new my_blog -d mysql -t slang
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
        @parsed_options["database"] = db
        @database = db
      end

      option_parser.on("-t TEMPLATE", "--template=TEMPLATE", "Select template engine (ecr, slang)") do |tmpl|
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
      option_parser.separator "  native  Cross-platform native app (macOS, iOS, Android)"
      option_parser.separator "          Uses Asset Pipeline UI, FSDD process managers,"
      option_parser.separator "          crystal-audio, and platform build scripts."
      option_parser.separator ""
      option_parser.separator "Examples:"
      option_parser.separator "  amber new my_app"
      option_parser.separator "  amber new my_app -d mysql -t slang"
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
        full_path_name = File.join(Dir.current, name)
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
      info "  shards install" unless no_deps
      info "  amber database create"
      info "  amber database migrate"
      info "  amber watch"
    end

    private def create_project_structure(path : String, name : String)
      # Create V2 directory structure
      dirs = [
        # Config
        "config", "config/environments", "config/initializers",
        # Database
        "db", "db/migrations",
        # Public assets
        "public", "public/css", "public/js", "public/img",
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

crystal: ">= 1.10.0"

license: UNLICENSED

targets:
  #{name}:
    main: src/#{name}.cr

dependencies:
  # Amber Framework V2
  amber:
    github: crimson-knight/amber
    branch: master

  # Grant ORM (ActiveRecord-style, replaces Granite in V2)
  grant:
    github: crimson-knight/grant
    branch: main

  # Asset Pipeline (native ESM, no Webpack/npm required)
  asset_pipeline:
    github: amberframework/asset_pipeline

  # File uploads (optional)
  gemma:
    github: crimson-knight/gemma

  # Database adapters (all required by Grant at compile time)
  pg:
    github: will/crystal-pg
  mysql:
    github: crystal-lang/crystal-mysql
  sqlite3:
    github: crystal-lang/crystal-sqlite3

development_dependencies:
  ameba:
    github: crystal-ameba/ameba
    version: ~> 1.6.4
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
model: grant
template: #{template}
AMBER

      File.write(File.join(path, ".amber.yml"), amber_content)
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

# Environment files (encrypted versions are safe to commit)
/config/environments/*.yml
!/config/environments/*.yml.enc

# Dependencies
/node_modules/

# Build artifacts
/tmp/
GITIGNORE

      File.write(File.join(path, ".gitignore"), gitignore_content)
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

      File.write(File.join(path, "src/#{name}.cr"), main_content)
    end

    private def create_config_files(path : String, name : String)
      app_config = <<-CONFIG
require "amber"

Amber::Server.configure do |settings|
  settings.name = "#{name}"
  settings.port = ENV["PORT"]?.try(&.to_i) || 3000
  settings.secret_key_base = ENV["SECRET_KEY_BASE"]? || "#{Random::Secure.hex(64)}"
end
CONFIG

      File.write(File.join(path, "config/application.cr"), app_config)
    end

    private def create_application_controller(path : String)
      controller_content = <<-CONTROLLER
class ApplicationController < Amber::Controller::Base
  LAYOUT = "application.#{template}"

  # Add shared before_action filters, helpers, etc.
  # All controllers inherit from this class.
end
CONTROLLER

      File.write(File.join(path, "src/controllers/application_controller.cr"), controller_content)
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

  pipeline :api do
    plug Amber::Pipe::Error.new
    plug Amber::Pipe::Logger.new
  end

  routes :web do
    get "/", HomeController, :index
  end

  # routes :api do
  # end
end
ROUTES

      File.write(File.join(path, "config/routes.cr"), routes_content)
    end

    private def create_environment_files(path : String, name : String)
      dev_config = <<-YML
database_url: postgres://localhost:5432/#{name}_development
YML

      test_config = <<-YML
database_url: postgres://localhost:5432/#{name}_test
YML

      prod_config = <<-YML
database_url: <%= ENV["DATABASE_URL"] %>
YML

      # Adjust database URLs based on selected database
      case database
      when "mysql"
        dev_config = <<-YML
database_url: mysql://localhost:3306/#{name}_development
YML
        test_config = <<-YML
database_url: mysql://localhost:3306/#{name}_test
YML
      when "sqlite"
        dev_config = <<-YML
database_url: sqlite3:./db/#{name}_development.db
YML
        test_config = <<-YML
database_url: sqlite3:./db/#{name}_test.db
YML
        prod_config = <<-YML
database_url: sqlite3:./db/#{name}_production.db
YML
      end

      File.write(File.join(path, "config/environments/development.yml"), dev_config)
      File.write(File.join(path, "config/environments/test.yml"), test_config)
      File.write(File.join(path, "config/environments/production.yml"), prod_config)
    end

    private def create_home_controller(path : String, name : String)
      home_controller = <<-CONTROLLER
class HomeController < ApplicationController
  def index
    render("index.#{template}")
  end
end
CONTROLLER

      File.write(File.join(path, "src/controllers/home_controller.cr"), home_controller)
    end

    private def create_views(path : String, name : String)
      if template == "slang"
        layout_content = <<-LAYOUT
doctype html
html
  head
    meta charset="utf-8"
    meta name="viewport" content="width=device-width, initial-scale=1"
    title #{name}
    link rel="stylesheet" href="/css/app.css"
  body
    == content
    script src="/js/app.js"
LAYOUT
        File.write(File.join(path, "src/views/layouts/application.slang"), layout_content)

        index_content = <<-VIEW
.welcome
  h1 = "Welcome to \#{Amber.settings.name}!"
  p Your Amber V2 application is running successfully.

  h2 Getting Started
  ul
    li
      | Edit this page:
      code src/views/home/index.slang
    li
      | Add routes:
      code config/routes.cr
    li
      | Generate a resource:
      code amber generate scaffold Post title:string body:text
VIEW
        File.write(File.join(path, "src/views/home/index.slang"), index_content)
      else
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
        File.write(File.join(path, "src/views/layouts/application.ecr"), layout_content)

        index_content = <<-VIEW
<div class="welcome">
  <h1>Welcome to <%= Amber.settings.name %>!</h1>
  <p>Your Amber V2 application is running successfully.</p>

  <h2>Getting Started</h2>
  <ul>
    <li>Edit this page: <code>src/views/home/index.ecr</code></li>
    <li>Add routes: <code>config/routes.cr</code></li>
    <li>Generate a resource: <code>amber generate scaffold Post title:string body:text</code></li>
  </ul>
</div>
VIEW
        File.write(File.join(path, "src/views/home/index.ecr"), index_content)
      end
    end

    private def create_spec_helper(path : String, name : String)
      spec_helper = <<-SPEC
require "spec"
require "../config/application"
require "../config/routes"
require "../src/**"

# Amber Testing Framework
require "amber/testing/testing"

# Include test helpers globally
include Amber::Testing::RequestHelpers
include Amber::Testing::Assertions
SPEC

      File.write(File.join(path, "spec/spec_helper.cr"), spec_helper)
    end

    private def create_home_controller_spec(path : String)
      spec_content = <<-SPEC
require "../spec_helper"

describe HomeController do
  include Amber::Testing::RequestHelpers
  include Amber::Testing::Assertions

  describe "GET /" do
    it "responds successfully" do
      response = get("/")
      assert_response_success(response)
    end
  end
end
SPEC

      File.write(File.join(path, "spec/controllers/home_controller_spec.cr"), spec_content)
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

      File.write(File.join(path, "db/seeds.cr"), seeds_content)
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

      File.write(File.join(path, "public/css/app.css"), css_content)

      # JavaScript
      js_content = <<-JS
// Application JavaScript
console.log("Amber V2 application loaded");
JS

      File.write(File.join(path, "public/js/app.js"), js_content)

      # robots.txt
      robots_content = <<-ROBOTS
User-agent: *
Disallow:
ROBOTS

      File.write(File.join(path, "public/robots.txt"), robots_content)

      # Placeholder favicon
      File.write(File.join(path, "public/favicon.ico"), "")

      # .keep for img
      File.write(File.join(path, "public/img/.keep"), "")
    end
  end
end

# Register the command
AmberCLI::Core::CommandRegistry.register("new", ["n"], AmberCLI::Commands::NewCommand)
