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
  # built with the Amber framework. This tool provides generators, database management,
  # development utilities, and more.
  #
  # ## Quick Start
  #
  # Create a new Amber application:
  # ```bash
  # amber new my_app
  # cd my_app
  # amber database create
  # amber database migrate
  # amber watch
  # ```
  #
  # ## Available Commands
  #
  # - **new** - Create a new Amber application
  # - **database** - Database operations and migrations
  # - **generate** - Generate application components
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
  # The `new` command creates a new Amber application with a complete directory
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
  # - `-t, --template=TEMPLATE` - Template engine (slang, ecr)
  # - `-r, --recipe=RECIPE` - Use a named recipe
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
  # amber new my_api -d mysql -t ecr
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
  # - **src/** - Application source code
  # - **config/** - Configuration files
  # - **db/** - Database migrations and seeds
  # - **spec/** - Test files
  # - **public/** - Static assets
  # - **shard.yml** - Dependency configuration
  # - **README.md** - Project documentation
  class NewCommand
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
  # ### Configuration
  #
  # Database configuration is handled through environment-specific YAML files
  # in the `config/environments/` directory:
  #
  # ```yaml
  # database_url: postgres://user:pass@localhost:5432/myapp_development
  # ```
  #
  # ### Supported Databases
  #
  # - **PostgreSQL** (`pg`) - Recommended for production
  # - **MySQL** (`mysql`) - Full feature support
  # - **SQLite** (`sqlite`) - Great for development and testing
  class DatabaseCommand
  end

  # ## Code Generation System
  #
  # Amber CLI provides a flexible and configurable code generation system
  # that can create models, controllers, views, and custom components.
  #
  # ### Built-in Generators
  #
  # The CLI includes several built-in generators:
  #
  # #### Model Generator
  # Creates a new model with associated files:
  # ```bash
  # amber generate model User name:String email:String
  # ```
  #
  # Generates:
  # - `src/models/user.cr` - Model class
  # - `spec/models/user_spec.cr` - Model spec
  # - `db/migrations/[timestamp]_create_users.sql` - Migration file
  #
  # #### Controller Generator
  # Creates a new controller:
  # ```bash
  # amber generate controller Posts
  # ```
  #
  # Generates:
  # - `src/controllers/posts_controller.cr` - Controller class
  # - `spec/controllers/posts_controller_spec.cr` - Controller spec
  #
  # #### Scaffold Generator
  # Creates a complete CRUD resource:
  # ```bash
  # amber generate scaffold Post title:String content:Text
  # ```
  #
  # Generates model, controller, views, and migration files.
  #
  # ### Custom Generators
  #
  # You can create custom generators by defining generator configuration files
  # in JSON or YAML format. These files specify templates, transformations,
  # and post-generation commands.
  #
  # #### Generator Configuration Format
  #
  # ```yaml
  # name: "my_custom_generator"
  # description: "Generates custom components"
  # template_variables:
  #   author: "Your Name"
  #   license: "MIT"
  # naming_conventions:
  #   snake_case: "underscore_separated"
  #   pascal_case: "CamelCase"
  # file_generation_rules:
  #   service:
  #     - template: "service_template"
  #       output_path: "src/services/{{snake_case}}_service.cr"
  # post_generation_commands:
  #   - "crystal tool format {{output_path}}"
  # ```
  #
  # ### Word Transformations
  #
  # The generator system includes intelligent word transformations:
  # - **snake_case** - `user_account`
  # - **pascal_case** - `UserAccount`
  # - **plural forms** - `users`, `UserAccounts`
  # - **singular forms** - `user`, `UserAccount`
  class GenerationSystem
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
  # #### Examples
  #
  # Basic watch mode:
  # ```bash
  # amber watch
  # ```
  #
  # Custom build and run commands:
  # ```bash
  # amber watch --build "crystal build src/my_app.cr --release" --run "./my_app"
  # ```
  #
  # Show current configuration:
  # ```bash
  # amber watch --info
  # ```
  #
  # ### Code Execution
  #
  # The `exec` command allows you to execute Crystal code within your
  # application's context, similar to Rails console.
  #
  # #### Usage
  # ```bash
  # amber exec [CODE_OR_FILE] [options]
  # ```
  #
  # #### Options
  #
  # - `-e, --editor=EDITOR` - Preferred editor (vim, nano, etc.)
  # - `-b, --back=TIMES` - Run previous command files
  #
  # #### Examples
  #
  # Execute inline code:
  # ```bash
  # amber exec 'puts "Hello from Amber!"'
  # ```
  #
  # Execute a Crystal file:
  # ```bash
  # amber exec my_script.cr
  # ```
  #
  # Open editor for interactive session:
  # ```bash
  # amber exec --editor nano
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
  # #### Options
  #
  # - `--json` - Output routes as JSON
  #
  # #### Examples
  #
  # Display routes in table format:
  # ```bash
  # amber routes
  # ```
  #
  # Output as JSON:
  # ```bash
  # amber routes --json
  # ```
  #
  # #### Sample Output
  #
  # ```
  # Verb      Controller       Action    Pipeline  Scope    URI Pattern
  # GET       HomeController   index     web       /        /
  # GET       PostsController  index     web       /        /posts
  # POST      PostsController  create    web       /        /posts
  # GET       PostsController  show      web       /        /posts/:id
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
  #
  # #### Options
  #
  # - `--no-plugs` - Hide plug information
  #
  # #### Examples
  #
  # Show all pipelines with plugs:
  # ```bash
  # amber pipelines
  # ```
  #
  # Show only pipeline names:
  # ```bash
  # amber pipelines --no-plugs
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
  # #### Options
  #
  # - `-e, --editor=EDITOR` - Preferred editor
  # - `--noedit` - Skip editing, just encrypt
  #
  # #### Examples
  #
  # Encrypt production environment:
  # ```bash
  # amber encrypt production
  # ```
  #
  # Encrypt staging with custom editor:
  # ```bash
  # amber encrypt staging --editor nano
  # ```
  #
  # Just encrypt without editing:
  # ```bash
  # amber encrypt production --noedit
  # ```
  #
  # ### Configuration Files
  #
  # Amber applications use several configuration files:
  #
  # #### `.amber.yml`
  # Project-specific configuration:
  # ```yaml
  # database: pg
  # language: slang
  # model: granite
  # watch:
  #   run:
  #     build_commands:
  #       - "crystal build ./src/my_app.cr -o bin/my_app"
  #     run_commands:
  #       - "bin/my_app"
  #     include:
  #       - "./config/**/*.cr"
  #       - "./src/**/*.cr"
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
  #
  # ### Options
  #
  # - `-u, --uninstall` - Uninstall plugin
  #
  # ### Examples
  #
  # Install a plugin:
  # ```bash
  # amber plugin my_plugin
  # ```
  #
  # Install with arguments:
  # ```bash
  # amber plugin auth_plugin --with-sessions
  # ```
  #
  # Uninstall a plugin:
  # ```bash
  # amber plugin my_plugin --uninstall
  # ```
  #
  # ### Plugin Development
  #
  # Plugins are Crystal shards that extend Amber functionality.
  # They can provide generators, middleware, or additional commands.
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
  #
  # ### Getting Help
  #
  # For detailed help on any command:
  # ```bash
  # amber [command] --help
  # ```
  #
  # For general help:
  # ```bash
  # amber --help
  # ```
  class CommandReference
  end

  # ## Configuration Reference
  #
  # Detailed reference for all configuration options and files.
  #
  # ### Generator Configuration
  #
  # Generator configurations define how code generation works:
  #
  # #### Configuration Schema
  #
  # ```yaml
  # name: string                    # Required: Generator name
  # description: string             # Optional: Description
  # template_variables:             # Optional: Default template variables
  #   key: value
  # naming_conventions:             # Optional: Word transformation rules
  #   snake_case: "underscore_format"
  #   pascal_case: "CamelCaseFormat"
  # file_generation_rules:          # Required: File generation rules
  #   generator_type:
  #     - template: "template_name"
  #       output_path: "path/{{variable}}.cr"
  #       transformations:          # Optional: Variable transformations
  #         custom_var: "{{name}}_custom"
  #       conditions:               # Optional: Generation conditions
  #         if_exists: "file.cr"
  # post_generation_commands:       # Optional: Commands to run after generation
  #   - "crystal tool format {{output_path}}"
  # dependencies:                   # Optional: Required dependencies
  #   - "some_shard"
  # ```
  #
  # ### Template Variables
  #
  # Available template variables for file generation:
  # - `{{name}}` - Original name provided
  # - `{{snake_case}}` - Snake case transformation
  # - `{{pascal_case}}` - Pascal case transformation
  # - `{{snake_case_plural}}` - Plural snake case
  # - `{{pascal_case_plural}}` - Plural pascal case
  # - `{{output_path}}` - Generated file path
  #
  # Custom variables can be defined in generator configuration.
  #
  # ### Watch Configuration
  #
  # Watch mode behavior is configurable in `.amber.yml`:
  #
  # ```yaml
  # watch:
  #   run:                          # Development environment
  #     build_commands:             # Commands to build the application
  #       - "mkdir -p bin"
  #       - "crystal build ./src/app.cr -o bin/app"
  #     run_commands:               # Commands to run the application
  #       - "bin/app"
  #     include:                    # Files to watch for changes
  #       - "./config/**/*.cr"
  #       - "./src/**/*.cr"
  #       - "./src/views/**/*.slang"
  #   test:                         # Test environment (optional)
  #     build_commands:
  #       - "crystal spec"
  #     run_commands:
  #       - "echo 'Tests completed'"
  #     include:
  #       - "./spec/**/*.cr"
  # ```
  #
  # # Configuration Reference
  #
  # Amber CLI uses several configuration mechanisms to customize behavior
  # for different project types and development workflows.
  #
  # ## Project Configuration (`.amber.yml`)
  #
  # The `.amber.yml` file in your project root configures project-specific settings:
  #
  # ```yaml
  # database: pg                    # Database type: pg, mysql, sqlite
  # language: slang                 # Template language: slang, ecr
  # model: granite                  # ORM: granite, jennifer
  # watch:
  #   run:
  #     build_commands:
  #       - "crystal build ./src/my_app.cr -o bin/my_app"
  #     run_commands:
  #       - "bin/my_app"
  #     include:
  #       - "./config/**/*.cr"
  #       - "./src/**/*.cr"
  # ```
  #
  # ## Generator Configuration
  #
  # Custom generators can be configured using JSON or YAML files in the
  # `generator_configs/` directory:
  #
  # ### Basic Generator Configuration
  #
  # ```yaml
  # name: "custom_model"
  # description: "Generate a custom model with validation"
  # template_directory: "templates/models"
  # amber_framework_version: "1.4.0"    # Amber framework version for new projects
  # custom_variables:
  #   author: "Your Name"
  #   license: "MIT"
  # naming_conventions:
  #   table_prefix: "app_"
  # file_generation_rules:
  #   - template_file: "model.cr.ecr"
  #     output_path: "src/models/{{snake_case}}.cr"
  #     transformations:
  #       class_name: "pascal_case"
  # ```
  #
  # ### Framework Version Configuration
  #
  # The `amber_framework_version` setting determines which version of the Amber 
  # framework gets used when creating new applications. This is separate from the
  # CLI tool version and allows you to:
  #
  # - Pin projects to specific Amber versions
  # - Test with different framework versions
  # - Maintain compatibility with existing projects
  #
  # Available template variables:
  # - `{{cli_version}}` - Current Amber CLI version
  # - `{{amber_framework_version}}` - Configured Amber framework version
  # - All word transformations (snake_case, pascal_case, etc.)
  #
  # ### Advanced Generator Features
  #
  # #### Conditional File Generation
  #
  # ```yaml
  # file_generation_rules:
  #   - template_file: "api_spec.cr.ecr"
  #     output_path: "spec/{{snake_case}}_spec.cr"
  #     conditions:
  #       generate_specs: "true"
  # ```
  #
  # #### Custom Transformations
  #
  # ```yaml
  # naming_conventions:
  #   namespace_prefix: "MyApp::"
  #   table_prefix: "my_app_"
  # transformations:
  #   full_class_name: "pascal_case"  # Will use namespace_prefix
  # ```
  #
  # ## Environment Configuration
  #
  # Environment-specific settings go in `config/environments/`:
  #
  # ```yaml
  # # config/environments/development.yml
  # database_url: "postgres://localhost/myapp_development"
  # amber_framework_version: "1.4.0"
  # 
  # # config/environments/production.yml  
  # database_url: ENV["DATABASE_URL"]
  # amber_framework_version: "1.4.0"
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
  # 2. Check generator configuration syntax
  # 3. Ensure template variables are properly defined
  #
  # ### Watch Mode Issues
  #
  # **Problem**: Files not being watched
  # **Solution**:
  # 1. Check file patterns in `.amber.yml`
  # 2. Verify files exist in specified directories
  # 3. Use `amber watch --info` to see current configuration
  #
  # ### Build Failures
  #
  # **Problem**: Crystal compilation errors
  # **Solution**:
  # 1. Run `shards install` to ensure dependencies are installed
  # 2. Check for syntax errors in generated files
  # 3. Verify all required files are present
  #
  # ### Plugin Issues
  #
  # **Problem**: Plugin not found or loading errors
  # **Solution**:
  # 1. Verify plugin is properly installed
  # 2. Check shard.yml dependencies
  # 3. Ensure plugin is compatible with current Amber version
  #
  # ### Getting More Help
  #
  # - Check the [Amber Framework documentation](https://docs.amberframework.org)
  # - Join the [Crystal community](https://crystal-lang.org/community/)
  # - Report issues on [GitHub](https://github.com/amberframework/amber_cli/issues)
  class Troubleshooting
  end
end 