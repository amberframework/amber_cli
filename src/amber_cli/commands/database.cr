require "micrate"
require "pg"
require "mysql"
require "sqlite3"
require "yaml"
require "../core/base_command"
require "../helpers/helpers"
require "../helpers/migration"
require "../config"
require "file_utils"

# The `database` command provides database management operations including
# migrations, seeding, and database status checks.
#
# ## Usage
# ```
# amber database [action][options]
# ```
#
# ## Actions
# - `migrate` - Run pending migrations
# - `rollback` - Rollback the last migration
# - `seed` - Run database seeds
# - `status` - Show migration status
# - `create` - Create the database
# - `drop` - Drop the database
#
# ## Examples
# ```
# # Run all pending migrations
# amber database migrate
#
# # Rollback the last migration
# amber database rollback
#
# # Check migration status
# amber database status
# ```
module AmberCLI::Commands
  class DatabaseCommand < AmberCLI::Core::BaseCommand
    Log = ::Log.for("database")

    MIGRATIONS_DIR        = "./db/migrations"
    CREATE_SQLITE_MESSAGE = "For sqlite3, the database will be created during the first migration."

    def help_description : String
      <<-EOS
      Performs database migrations and maintenance tasks. Powered by micrate.

      Commands:
        drop      drops the database
        create    creates the database
        migrate   migrate the database to the most recent version available
        rollback  roll back the database version by 1
        redo      re-run the latest database migration
        status    dump the migration status for the current database
        version   print the current version of the database
        seed      initialize the database with seed data
      EOS
    end

    def setup_command_options
      option_parser.separator ""
      option_parser.separator "Usage: amber database [COMMAND] [options]"
      option_parser.separator ""
      option_parser.separator "Commands:"
      option_parser.separator "  drop      drops the database"
      option_parser.separator "  create    creates the database"
      option_parser.separator "  migrate   migrate the database to the most recent version"
      option_parser.separator "  rollback  roll back the database version by 1"
      option_parser.separator "  redo      re-run the latest database migration"
      option_parser.separator "  status    dump the migration status for the current database"
      option_parser.separator "  version   print the current version of the database"
      option_parser.separator "  seed      initialize the database with seed data"
      option_parser.separator ""
      option_parser.separator "Examples:"
      option_parser.separator "  amber database create"
      option_parser.separator "  amber database migrate"
      option_parser.separator "  amber database rollback"
    end

    def validate_arguments
      if remaining_arguments.empty?
        # No arguments provided, show help
        puts option_parser
        exit(0)
      end
    end

    def execute
      process_commands(remaining_arguments)
    rescue e : DB::ConnectionRefused
      exit! "Connection unsuccessful: #{database_url}", error: true
    rescue e : Exception
      exit! e.message || "Unknown error", error: true
    end

    private def process_commands(commands)
      commands.each do |command|
        url = database_url
        case command
        when "drop"
          Micrate::Cli.drop_database(url)
        when "create"
          Micrate::Cli.create_database(url)
        when "seed"
          Amber::CLI::Helpers.run("crystal db/seeds.cr", wait: true)
          info "Seeded database"
        when "migrate"
          Micrate::Cli.run_up(url, MIGRATIONS_DIR)
        when "rollback"
          Micrate::Cli.run_down(url, MIGRATIONS_DIR)
        when "redo"
          Micrate::Cli.run_redo(url, MIGRATIONS_DIR)
        when "status"
          Micrate::Cli.run_status(url, MIGRATIONS_DIR)
        when "version"
          Micrate::Cli.run_dbversion(url, MIGRATIONS_DIR)
        when "connect"
          connect_to_database
        else
          error "Unknown command: #{command}"
          puts option_parser
          exit(1)
        end
      end
    end

    private def connect_to_database
      Process.exec(command_line_tool, {database_cli_argument})
      exit!
    end

    private def command_line_tool
      case database_type
      when "pg"
        "psql"
      when "mysql"
        "mysql"
      when "sqlite"
        "sqlite3"
      else
        exit! "invalid database configuration", error: true
      end
    end

    private def database_type
      # Try to determine from URL
      url = database_url
      return "pg" if url.starts_with?("postgres://") || url.starts_with?("postgresql://")
      return "mysql" if url.starts_with?("mysql://")
      return "sqlite" if url.starts_with?("sqlite3://")

      # Fallback to config file or environment
      config_file = ".amber.yml"
      if File.exists?(config_file)
        content = File.read(config_file)
        if content.includes?("database: pg")
          "pg"
        elsif content.includes?("database: mysql")
          "mysql"
        elsif content.includes?("database: sqlite")
          "sqlite"
        else
          "pg" # default
        end
      else
        "pg" # default
      end
    end

    private def database_url : String
      ENV["DATABASE_URL"]? || ENV["AMBER_DATABASE_URL"]? || environment_database_url || default_database_url
    end

    private def environment_database_url : String?
      environment = ENV["AMBER_ENV"]? || "development"
      config_file = "config/environments/#{environment}.yml"
      return unless File.exists?(config_file)

      document = YAML.parse(File.read(config_file))
      document["database"]?.try(&.["url"]?).try(&.as_s?)
    rescue ex : YAML::ParseException
      warning "Could not parse #{config_file}: #{ex.message}"
      nil
    end

    private def default_database_url : String
      name = Amber::CLI::Config.get_name
      environment = ENV["AMBER_ENV"]? || "development"

      case database_type
      when "mysql"
        "mysql://localhost:3306/#{name}_#{environment}"
      when "sqlite"
        "sqlite3:./db/#{name}_#{environment}.db"
      else
        "postgres://localhost:5432/#{name}_#{environment}"
      end
    end

    private def database_cli_argument : String
      url = database_url
      database_type == "sqlite" ? url.sub(/^sqlite3:(?:\/\/)?/, "") : url
    end
  end
end

# Register the command
AmberCLI::Core::CommandRegistry.register("database", ["db"], AmberCLI::Commands::DatabaseCommand)
