require "../core/base_command"
require "../generators/native_app"
require "../static_assets"

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
# # Create a new web app with SQLite, Grant, and ECR (defaults)
# amber new my_blog
#
# # Create a web app backed by MySQL instead
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

    getter database : String = "sqlite"
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
      option_parser.separator "  web     Web application with HTTP server, Grant ORM, SQLite, routes, and views (default)"
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
      info "  amber generate scaffold Pet name:string:required species:string:required"
      info "  amber database migrate"
      info "  amber watch"
      info "  # Choose -d pg or -d mysql when you need a server database."
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
        # Authored assets and generated public output
        "app", "app/assets", "app/assets/stylesheets", "app/assets/javascript",
        "app/assets/images", "app/assets/fonts", "app/assets/files",
        "bin", "public", "public/assets",
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
      create_readme(path, name)
      create_gitignore(path)
      create_main_file(path, name)
      create_config_files(path, name)
      create_assets_config(path)
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

      build_assets(path)

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
    version: 2.0.0-beta.4
  grant:
    github: crimson-knight/grant
    commit: 2665a978b43ac608c68cde9243821f8f8f053372
  asset_pipeline:
    github: amberframework/asset_pipeline
    commit: 67659880b11ef6cb91aa890d6f13fbc98000996a
#{database_shard_dependency}
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
model: grant
template: ecr
AMBER

      write_text(File.join(path, ".amber.yml"), amber_content)
    end

    private def create_readme(path : String, name : String)
      readme_content = <<-README
# #{name}

An ECR web application generated by Amber CLI for Amber `2.0.0-beta.4`.

## Run it

```bash
shards install
amber assets build
amber assets check
crystal spec
amber generate scaffold Pet name:string:required species:string:required adopted:bool
amber database migrate
amber watch
```

Open <http://127.0.0.1:3000> for the starter page or
<http://127.0.0.1:3000/pets/new> after generating the example scaffold.

Write CSS in `app/assets/stylesheets/`, browser modules in
`app/assets/javascript/`, images in `app/assets/images/`, fonts in
`app/assets/fonts/`, and other downloads in `app/assets/files/`. The asset build
fingerprints those sources into the generated, gitignored `public/assets/`
directory and writes `public/assets/manifest.json`. Edit the `app/assets/`
sources, never the compiled copies. `amber watch` rebuilds assets before it
recompiles the application.

The scaffold writes its Grant model to `src/models/pet.cr`, request schema to
`src/schemas/pet_schema.cr`, controller to `src/controllers/pet_controller.cr`,
ECR views to `src/views/pet/`, SQL migration to `db/migrations/`, specs to
`spec/`, and resource route to `config/routes.cr`.

This application uses #{database} through `config/database.cr`. SQLite is the
zero-setup default; generate the app with `-d pg` or `-d mysql` to select a
server database. Set `DATABASE_URL` to override the environment YAML URL.

## Production configuration

Set at least `AMBER_SERVER_SECRET_KEY_BASE` and `DATABASE_URL`. See the
[Amber V2 beta guide](https://github.com/amberframework/amber/blob/v2.0.0-beta.4/docs/beta-installation.md).
README

      write_text(File.join(path, "README.md"), readme_content)
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
/public/assets/
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
require "./assets"
CONFIG

      write_text(File.join(path, "config/application.cr"), app_config)

      database_config = <<-CONFIG
require "amber"
require "grant"
require "grant/adapter/#{database_adapter_require}"

Grant::Connections << Grant::Adapter::#{database_adapter_class}.new(
  name: "primary",
  url: ENV["DATABASE_URL"]? || Amber.settings.database_url
)
CONFIG

      write_text(File.join(path, "config/database.cr"), database_config)
    end

    private def create_assets_config(path : String)
      assets_config = <<-CONFIG
Amber::Assets.configure(manifest_path: "public/assets/manifest.json")
CONFIG

      write_text(File.join(path, "config/assets.cr"), assets_config)
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
  <%= favicon_tag("images/favicon.svg") %>
  <%= stylesheet_link_tag("stylesheets/app.css") %>
</head>
<body>
  <%= content %>
  <%= javascript_importmap_tag({"app" => "javascript/app.js"}, preload: ["javascript/app.js"]) %>
  <script type="module">import "app";</script>
</body>
</html>
LAYOUT
      write_text(File.join(path, "src/views/layouts/application.ecr"), layout_content)

      index_content = <<-VIEW
<div class="amber-starter">
  <header class="starter-nav">
    <a class="starter-brand" href="/" aria-label="<%= Amber.settings.name %> home">
      <%= image_tag("images/amber-crystal.svg", class: "starter-crystal", alt: "") %>
      <span><%= Amber.settings.name %></span>
    </a>
    <span class="starter-status"><span aria-hidden="true"></span> Amber V2 beta</span>
  </header>

  <main class="starter-main">
    <section class="starter-hero" aria-labelledby="starter-title">
      <p class="starter-eyebrow">Amber V2 · Web application</p>
      <h1 id="starter-title">Your new idea<br><em>starts here.</em></h1>
      <p class="starter-intro"><strong><%= Amber.settings.name %></strong> is running. Your first route, view, and locally served CSS and JavaScript are ready to shape.</p>
      <div class="starter-proof" aria-label="Application status">
        <span><b>◆</b> Server rendered</span>
        <span><b>◇</b> Crystal powered</span>
        <span><b>✓</b> Ready to customize</span>
      </div>
    </section>

    <section class="starter-next" aria-labelledby="starter-next-title">
      <div class="starter-section-heading">
        <p>First edits</p>
        <h2 id="starter-next-title">Make it yours.</h2>
      </div>
      <ol class="starter-steps">
        <li><span>01</span><div><strong>Edit the page</strong><code>src/views/home/index.ecr</code></div></li>
        <li><span>02</span><div><strong>Add a route</strong><code>config/routes.cr</code></div></li>
        <li><span>03</span><div><strong>Generate a controller</strong><code>amber generate controller Posts</code></div></li>
      </ol>
    </section>
  </main>

  <footer class="starter-footer">
    <span>Generated by Amber CLI</span>
    <span>Built with Crystal</span>
  </footer>
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
require "../config/*"
require "../src/models/**"

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
/* Amber V2 starter styles */

:root {
  color-scheme: light;
  --amber-paper: #fffaf2;
  --amber-paper-deep: #f7ead7;
  --amber-ink: #261913;
  --amber-muted: #745e52;
  --amber-line: #dec9b4;
  --amber-accent: #e96918;
  --amber-accent-deep: #a93d08;
  --amber-gold: #f3a348;
  --amber-green: #377a55;
  --amber-shadow: 0 22px 70px rgba(74, 42, 23, 0.13);
  font-family: ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  line-height: 1.5;
  color: var(--amber-ink);
  background: var(--amber-paper);
}

* {
  box-sizing: border-box;
}

html,
body {
  min-height: 100%;
  margin: 0;
}

body {
  color: var(--amber-ink);
  background: var(--amber-paper);
}

a {
  color: inherit;
}

.amber-starter {
  position: relative;
  min-height: 100vh;
  overflow: hidden;
  background:
    radial-gradient(circle at 78% 21%, rgba(243, 163, 72, 0.22), transparent 22rem),
    radial-gradient(circle at 12% 78%, rgba(233, 105, 24, 0.09), transparent 26rem),
    linear-gradient(145deg, #fffdf9 0%, var(--amber-paper) 48%, var(--amber-paper-deep) 100%);
}

.amber-starter::before,
.amber-starter::after {
  position: absolute;
  z-index: 0;
  content: "";
  pointer-events: none;
}

.amber-starter::before {
  top: 8rem;
  right: -13rem;
  width: 38rem;
  height: 38rem;
  border: 1px solid rgba(169, 61, 8, 0.12);
  border-radius: 50%;
}

.amber-starter::after {
  top: 15rem;
  right: 9%;
  width: 4.5rem;
  height: 6rem;
  opacity: 0.17;
  background: center / contain no-repeat url("../images/amber-crystal.svg");
  transform: rotate(14deg);
}

.starter-nav,
.starter-main,
.starter-footer {
  position: relative;
  z-index: 1;
  width: min(1120px, calc(100% - 40px));
  margin-inline: auto;
}

.starter-nav {
  display: flex;
  min-height: 78px;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid var(--amber-line);
}

.starter-brand {
  display: inline-flex;
  align-items: center;
  gap: 11px;
  font-family: ui-serif, Georgia, Cambria, "Times New Roman", serif;
  font-size: 1.06rem;
  font-weight: 800;
  text-decoration: none;
}

.starter-crystal {
  display: inline-block;
  width: 23px;
  height: 31px;
  flex: 0 0 auto;
  object-fit: contain;
  filter: drop-shadow(0 4px 6px rgba(169, 61, 8, 0.24));
}

.starter-status {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 7px 11px;
  border: 1px solid var(--amber-line);
  border-radius: 999px;
  color: var(--amber-muted);
  background: rgba(255, 253, 249, 0.7);
  font-size: 0.7rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.starter-status > span {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--amber-green);
  box-shadow: 0 0 0 4px rgba(55, 122, 85, 0.12);
}

.starter-main {
  display: grid;
  align-items: end;
  grid-template-columns: minmax(0, 1.12fr) minmax(320px, 0.88fr);
  gap: clamp(44px, 8vw, 112px);
  padding-block: clamp(80px, 11vw, 150px) clamp(88px, 12vw, 160px);
}

.starter-eyebrow,
.starter-section-heading p {
  margin: 0 0 17px;
  color: var(--amber-accent-deep);
  font-size: 0.72rem;
  font-weight: 850;
  letter-spacing: 0.15em;
  text-transform: uppercase;
}

.starter-eyebrow::before {
  display: inline-block;
  width: 30px;
  height: 1px;
  margin-right: 10px;
  background: currentColor;
  content: "";
  vertical-align: 0.28em;
}

.starter-hero h1,
.starter-section-heading h2 {
  margin: 0;
  font-family: ui-serif, Georgia, Cambria, "Times New Roman", serif;
  letter-spacing: -0.045em;
}

.starter-hero h1 {
  max-width: 760px;
  font-size: clamp(3.7rem, 8.4vw, 7.4rem);
  line-height: 0.84;
}

.starter-hero h1 em {
  color: var(--amber-accent);
  font-weight: 650;
}

.starter-intro {
  max-width: 620px;
  margin: 34px 0 0;
  color: var(--amber-muted);
  font-size: clamp(1rem, 1.7vw, 1.2rem);
}

.starter-intro strong {
  color: var(--amber-ink);
}

.starter-proof {
  display: flex;
  flex-wrap: wrap;
  gap: 9px;
  margin-top: 28px;
}

.starter-proof span {
  padding: 8px 11px;
  border: 1px solid var(--amber-line);
  border-radius: 999px;
  background: rgba(255, 253, 249, 0.76);
  color: var(--amber-muted);
  font-size: 0.72rem;
  font-weight: 750;
}

.starter-proof b {
  margin-right: 5px;
  color: var(--amber-accent);
}

.starter-next {
  padding: clamp(28px, 4vw, 44px);
  border: 1px solid var(--amber-line);
  border-radius: 22px;
  background: rgba(255, 253, 249, 0.78);
  box-shadow: var(--amber-shadow);
  backdrop-filter: blur(12px);
}

.starter-section-heading h2 {
  font-size: clamp(2rem, 4vw, 3.2rem);
  line-height: 0.98;
}

.starter-steps {
  display: grid;
  gap: 0;
  margin: 30px 0 0;
  padding: 0;
  list-style: none;
}

.starter-steps li {
  display: grid;
  align-items: start;
  grid-template-columns: 34px minmax(0, 1fr);
  gap: 15px;
  padding-block: 17px;
  border-top: 1px solid var(--amber-line);
}

.starter-steps li > span {
  color: var(--amber-accent-deep);
  font: 800 0.68rem/1.5 ui-monospace, SFMono-Regular, Consolas, monospace;
}

.starter-steps strong {
  display: block;
  margin-bottom: 6px;
  font-size: 0.88rem;
}

.starter-steps code {
  display: inline-block;
  max-width: 100%;
  overflow-wrap: anywhere;
  color: var(--amber-muted);
  font: 0.76rem/1.55 ui-monospace, SFMono-Regular, Consolas, monospace;
}

.starter-footer {
  display: flex;
  min-height: 68px;
  align-items: center;
  justify-content: space-between;
  border-top: 1px solid var(--amber-line);
  color: var(--amber-muted);
  font-size: 0.72rem;
}

@media (max-width: 780px) {
  .starter-main {
    grid-template-columns: 1fr;
    padding-block: 72px 92px;
  }

  .starter-hero h1 {
    font-size: clamp(3.5rem, 17vw, 5.5rem);
  }

  .starter-next {
    padding: 28px 24px;
  }
}

@media (max-width: 480px) {
  .starter-nav,
  .starter-main,
  .starter-footer {
    width: min(100% - 28px, 1120px);
  }

  .starter-status {
    padding: 6px 8px;
    font-size: 0.61rem;
  }

  .starter-hero h1 {
    font-size: 3.45rem;
  }

  .starter-footer {
    align-items: flex-start;
    flex-direction: column;
    justify-content: center;
    gap: 3px;
  }
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

      write_text(File.join(path, "app/assets/stylesheets/app.css"), css_content)

      # JavaScript
      js_content = <<-JS
// Application JavaScript entry point.
// Add local modules under app/assets/javascript and map stable names in the ECR layout.
document.documentElement.dataset.javascript = "ready";
JS

      write_text(File.join(path, "app/assets/javascript/app.js"), js_content)

      logo_svg = <<-SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" role="img" aria-labelledby="amber-crystal-title">
  <title id="amber-crystal-title">Amber crystal</title>
  <path fill="#f7a13b" d="M64 5 111 36 96 105 64 123 32 105 17 36Z"/>
  <path fill="#e96918" d="m64 5 15 48-15 70-32-18 11-52Z"/>
  <path fill="#ffca6e" d="m64 5 47 31-32 17Z"/>
  <path fill="#a93d08" d="m79 53 32-17-15 69-32 18Z"/>
</svg>
SVG
      write_text(File.join(path, "app/assets/images/amber-crystal.svg"), logo_svg)

      favicon_svg = <<-SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <path fill="#e96918" d="M32 3 56 19 48 53 32 62 16 53 8 19Z"/>
  <path fill="#ffbd5a" d="m32 3 8 24-8 35-16-9 6-26Z"/>
</svg>
SVG
      write_text(File.join(path, "app/assets/images/favicon.svg"), favicon_svg)

      # robots.txt
      robots_content = <<-ROBOTS
User-agent: *
Disallow:
ROBOTS

      write_text(File.join(path, "public/robots.txt"), robots_content)

      %w[app/assets/fonts app/assets/files].each do |directory|
        File.write(File.join(path, directory, ".gitkeep"), "")
      end
    end

    private def build_assets(path : String)
      manifest = AmberCLI::StaticAssets.build(path)
      info "Compiled #{manifest.assets.size} fingerprinted static assets"
    rescue ex : AssetPipeline::StaticAssets::Error
      error ex.message || "Asset compilation failed; the project files were kept."
      info "Run 'amber assets build' in #{path} after resolving the error."
      exit!(error: true)
    end

    private def write_text(path : String, content : String)
      File.write(path, content.ends_with?("\n") ? content : "#{content}\n")
    end

    private def database_shard_dependency : String
      case database
      when "pg"
        <<-YAML
          pg:
            github: will/crystal-pg
            version: 0.30.0
        YAML
      when "mysql"
        <<-YAML
          mysql:
            github: crimson-knight/crystal-mysql
            commit: c061324dcef89a200a7a3f86a59b2ebf03f83602
        YAML
      else
        <<-YAML
          sqlite3:
            github: crystal-lang/crystal-sqlite3
            version: 0.23.0
        YAML
      end
    end

    private def database_adapter_require : String
      database == "sqlite" ? "sqlite" : database
    end

    private def database_adapter_class : String
      case database
      when "pg"    then "Pg"
      when "mysql" then "Mysql"
      else              "Sqlite"
      end
    end
  end
end

# Register the command
AmberCLI::Core::CommandRegistry.register("new", ["n"], AmberCLI::Commands::NewCommand)
