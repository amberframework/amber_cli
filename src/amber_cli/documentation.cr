# Amber CLI Documentation
#
# This module contains comprehensive documentation for the Amber CLI tool.
# It is designed to be processed by Crystal's `crystal docs` command to generate
# HTML documentation that can be hosted on GitHub Pages.
#
# Usage:
#   crystal docs
#   # Documentation will be generated in the ./docs directory
#
# For more information about Crystal documentation formatting, see:
# https://crystal-lang.org/reference/1.16/syntax_and_semantics/documenting_code.html

module AmberCLI::Documentation
  # # Amber CLI Documentation
  #
  # Amber CLI is a powerful command-line tool for managing Crystal web applications
  # built with the Amber V2 framework. This tool provides generators, database management,
  # development utilities, and more.
  #
  # ## Quick Start
  #
  # Create a new Amber V2 application:
  # ```bash
  # amber new my_app
  # cd my_app
  # shards install
  # amber database create
  # amber database migrate
  # amber watch
  # ```
  #
  # ## Available Commands
  #
  # - **new** - Create a new Amber V2 application
  # - **generate** - Generate application components
  # - **database** - Database operations and migrations
  # - **routes** - Display application routes
  # - **watch** - Development server with file watching
  # - **encrypt** - Encrypt/decrypt environment files
  # - **exec** - Execute Crystal code in application context
  # - **plugin** - Plugin management
  # - **pipelines** - Display pipeline configuration
  class Overview
  end

  # ## Creating New Applications
  #
  # The `new` command creates a new Amber V2 application with a complete directory
  # structure and configuration files.
  #
  # ### Usage
  # ```bash
  # amber new [NAME] [options]
  # ```
  #
  # ### Options
  #
  # - `-d, --database=DATABASE` - Database engine (pg, mysql, sqlite)
  # - `-t, --template=TEMPLATE` - Template engine (ecr, slang)
  # - `-y, --assume-yes` - Skip interactive prompts
  # - `--no-deps` - Don't install dependencies
  #
  # ### Examples
  #
  # Create a basic application:
  # ```bash
  # amber new my_blog
  # ```
  #
  # Create with specific database and template:
  # ```bash
  # amber new my_api -d mysql -t slang
  # ```
  #
  # Create in current directory:
  # ```bash
  # amber new . -d sqlite
  # ```
  #
  # ### Generated Structure
  #
  # The new command creates:
  # - **src/** - Application source code (controllers, models, schemas, jobs, mailers, channels)
  # - **config/** - Configuration files (application.cr, routes.cr, environments/)
  # - **db/** - Database migrations and seeds
  # - **spec/** - Test files for all component types
  # - **public/** - Static assets (css, js, img)
  # - **shard.yml** - Dependency configuration
  # - **.amber.yml** - Project configuration
  # - **.gitignore** - Git ignore rules
  class NewCommand
  end

  # ## Code Generation System
  #
  # The `generate` command creates application components following V2 patterns.
  #
  # ### Available Generators
  #
  # #### Model Generator
  # Creates a model with associated migration and spec:
  # ```bash
  # amber generate model User name:string email:string
  # ```
  #
  # #### Controller Generator
  # Creates a controller with views and spec using `Amber::Testing`:
  # ```bash
  # amber generate controller Posts index show
  # ```
  #
  # #### Scaffold Generator
  # Creates a complete CRUD resource with schema-based validation:
  # ```bash
  # amber generate scaffold Post title:string body:text published:bool
  # ```
  #
  # #### Migration Generator
  # Creates a database migration file:
  # ```bash
  # amber generate migration AddStatusToUsers
  # ```
  #
  # #### Job Generator
  # Creates a background job class extending `Amber::Jobs::Job`:
  # ```bash
  # amber generate job SendNotification --queue=mailers --max-retries=5
  # ```
  #
  # #### Mailer Generator
  # Creates a mailer class extending `Amber::Mailer::Base`:
  # ```bash
  # amber generate mailer User --actions=welcome,notify
  # ```
  #
  # #### Schema Generator
  # Creates a schema definition extending `Amber::Schema::Definition`:
  # ```bash
  # amber generate schema User name:string email:string:required age:int32
  # ```
  #
  # #### Channel Generator
  # Creates a WebSocket channel extending `Amber::WebSockets::Channel`:
  # ```bash
  # amber generate channel Chat
  # ```
  #
  # #### API Generator
  # Creates an API-only controller with model and schema:
  # ```bash
  # amber generate api Product name:string price:float
  # ```
  #
  # #### Auth Generator
  # Creates an authentication system with login and registration:
  # ```bash
  # amber generate auth
  # ```
  #
  # ### Field Types
  #
  # Available field types for model, scaffold, schema, and api generators:
  # - `string` - VARCHAR(255) / String
  # - `text` - TEXT / String
  # - `integer`, `int`, `int32` - INTEGER / Int32
  # - `int64` - BIGINT / Int64
  # - `float`, `float64` - DOUBLE PRECISION / Float64
  # - `decimal` - DECIMAL(10,2) / Float64
  # - `bool`, `boolean` - BOOLEAN / Bool
  # - `time`, `timestamp` - TIMESTAMP / Time
  # - `email` - VARCHAR(255) / String (with email format validation)
  # - `uuid` - VARCHAR(255) / String (with UUID format validation)
  # - `reference` - BIGINT / Int64
  #
  # ### Schema Field Format
  #
  # Schema fields support a `:required` suffix:
  # ```bash
  # amber generate schema User name:string:required email:email:required age:int32
  # ```
  class GenerationSystem
  end

  # ## Database Management
  #
  # The `database` command provides comprehensive database management capabilities
  # powered by Micrate. It supports PostgreSQL, MySQL, and SQLite.
  #
  # ### Usage
  # ```bash
  # amber database [COMMAND] [options]
  # ```
  #
  # ### Available Commands
  #
  # #### `create`
  # Creates the database specified in your configuration.
  # ```bash
  # amber database create
  # ```
  #
  # #### `drop`
  # Drops the database (use with caution).
  # ```bash
  # amber database drop
  # ```
  #
  # #### `migrate`
  # Runs all pending migrations to bring the database up to date.
  # ```bash
  # amber database migrate
  # ```
  #
  # #### `rollback`
  # Rolls back the last migration.
  # ```bash
  # amber database rollback
  # ```
  #
  # #### `redo`
  # Rolls back and re-runs the latest migration.
  # ```bash
  # amber database redo
  # ```
  #
  # #### `status`
  # Shows the current migration status.
  # ```bash
  # amber database status
  # ```
  #
  # #### `version`
  # Displays the current database version.
  # ```bash
  # amber database version
  # ```
  #
  # #### `seed`
  # Runs the database seed file (`db/seeds.cr`).
  # ```bash
  # amber database seed
  # ```
  #
  # ### Supported Databases
  #
  # - **PostgreSQL** (`pg`) - Recommended for production
  # - **MySQL** (`mysql`) - Full feature support
  # - **SQLite** (`sqlite`) - Great for development and testing
  class DatabaseCommand
  end

  # ## Development Tools
  #
  # Amber CLI provides several tools to streamline development workflow.
  #
  # ### Watch Mode
  #
  # The `watch` command starts a development server that automatically rebuilds
  # and restarts your application when files change.
  #
  # #### Usage
  # ```bash
  # amber watch [options]
  # ```
  #
  # #### Options
  #
  # - `-n, --name=NAME` - Application process name
  # - `-b, --build=BUILD` - Custom build command
  # - `-r, --run=RUN` - Custom run command
  # - `-w, --watch=FILES` - Files to watch (comma-separated)
  # - `-i, --info` - Show current configuration
  #
  # ### Code Execution
  #
  # The `exec` command allows you to execute Crystal code within your
  # application's context.
  #
  # #### Usage
  # ```bash
  # amber exec [CODE_OR_FILE] [options]
  # ```
  class DevelopmentTools
  end

  # ## Application Analysis
  #
  # Amber CLI provides tools to analyze and understand your application structure.
  #
  # ### Routes Display
  #
  # The `routes` command shows all defined routes in your application.
  #
  # #### Usage
  # ```bash
  # amber routes [options]
  # ```
  #
  # ### Pipeline Analysis
  #
  # The `pipelines` command displays pipeline configuration and associated plugs.
  #
  # #### Usage
  # ```bash
  # amber pipelines [options]
  # ```
  class ApplicationAnalysis
  end

  # ## Security and Configuration
  #
  # ### Environment File Encryption
  #
  # The `encrypt` command provides secure environment file management.
  #
  # #### Usage
  # ```bash
  # amber encrypt [ENVIRONMENT] [options]
  # ```
  #
  # ### Configuration Files
  #
  # Amber V2 applications use several configuration files:
  #
  # #### `.amber.yml`
  # Project-specific configuration:
  # ```yaml
  # app: myapp
  # database: pg
  # language: crystal
  # model: grant
  # template: ecr
  # ```
  #
  # #### Environment Files
  # - `config/environments/development.yml`
  # - `config/environments/production.yml`
  # - `config/environments/test.yml`
  class SecurityAndConfiguration
  end

  # ## Plugin System
  #
  # The `plugin` command manages application plugins and extensions.
  #
  # ### Usage
  # ```bash
  # amber plugin [NAME] [args...] [options]
  # ```
  class PluginSystem
  end

  # ## Command Reference
  #
  # Complete reference of all available commands and their options.
  #
  # ### Global Options
  #
  # These options are available for all commands:
  # - `--no-color` - Disable colored output
  # - `-h, --help` - Show command help
  # - `--version` - Show version information
  #
  # ### Command Categories
  #
  # #### Project Management
  # - `new` - Create new applications
  # - `plugin` - Manage plugins
  #
  # #### Code Generation
  # - `generate` - Generate application components
  #   - `model` - Models with migrations
  #   - `controller` - Controllers with views
  #   - `scaffold` - Full CRUD resources
  #   - `migration` - Database migrations
  #   - `job` - Background jobs (Amber::Jobs::Job)
  #   - `mailer` - Email mailers (Amber::Mailer::Base)
  #   - `schema` - Request schemas (Amber::Schema::Definition)
  #   - `channel` - WebSocket channels (Amber::WebSockets::Channel)
  #   - `api` - API-only controllers
  #   - `auth` - Authentication system
  #
  # #### Database Operations
  # - `database` - All database-related commands
  #
  # #### Development
  # - `watch` - Development server
  # - `exec` - Code execution
  #
  # #### Analysis
  # - `routes` - Route analysis
  # - `pipelines` - Pipeline analysis
  #
  # #### Security
  # - `encrypt` - Environment encryption
  class CommandReference
  end

  # ## Configuration Reference
  #
  # Detailed reference for all configuration options and files.
  #
  # ### Generator Configuration
  #
  # Generator configurations define how code generation works. The CLI uses
  # inline heredoc templates by default for zero-configuration experience.
  #
  # ### Watch Configuration
  #
  # Watch mode behavior is configurable in `.amber.yml`:
  #
  # ```yaml
  # watch:
  #   run:
  #     build_commands:
  #       - "mkdir -p bin"
  #       - "crystal build ./src/app.cr -o bin/app"
  #     run_commands:
  #       - "bin/app"
  #     include:
  #       - "./config/**/*.cr"
  #       - "./src/**/*.cr"
  #       - "./src/views/**/*.ecr"
  # ```
  class ConfigurationReference
  end

  # ## Troubleshooting
  #
  # Common issues and their solutions.
  #
  # ### Database Connection Issues
  #
  # **Problem**: `Connection unsuccessful` error
  # **Solution**:
  # 1. Verify database server is running
  # 2. Check connection string in environment configuration
  # 3. Ensure database exists (run `amber database create`)
  #
  # ### Generation Failures
  #
  # **Problem**: Template not found errors
  # **Solution**:
  # 1. Verify template files exist in expected locations
  # 2. Check `.amber.yml` for correct template setting (ecr or slang)
  # 3. Ensure template variables are properly defined
  #
  # ### Getting More Help
  #
  # - Check the [Amber Framework documentation](https://docs.amberframework.org)
  # - Join the [Crystal community](https://crystal-lang.org/community/)
  # - Report issues on [GitHub](https://github.com/amberframework/amber_cli/issues)
  class Troubleshooting
  end
end
