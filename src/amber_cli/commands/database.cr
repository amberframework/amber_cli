require "micrate"
require "pg"
require "mysql"
require "sqlite3"
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
      connect_to_database if remaining_arguments.empty?
      process_commands(remaining_arguments)
    rescue e : DB::ConnectionRefused
      exit! "Connection unsuccessful: #{Micrate::DB.connection_url || "unknown"}", error: true
    rescue e : Exception
      exit! e.message || "Unknown error", error: true
    end

    private def process_commands(commands)
      commands.each do |command|
        Micrate::DB.connection_url = database_url
        case command
        when "drop"
          drop_database
        when "create"
          create_database
        when "seed"
          Amber::CLI::Helpers.run("crystal db/seeds.cr", wait: true, shell: true)
          info "Seeded database"
        when "migrate"
          migrate
        when "rollback"
          Micrate::Cli.run_down
        when "redo"
          Micrate::Cli.run_redo
        when "status"
          Micrate::Cli.run_status
        when "version"
          Micrate::Cli.run_dbversion
        when "connect"
          connect_to_database
        else
          error "Unknown command: #{command}"
          puts option_parser
          exit(1)
        end
      end
    end

    private def migrate
      Micrate::Cli.run_up
    rescue e : IndexError
      exit! "No migrations to run in #{MIGRATIONS_DIR}."
    end

    private def drop_database
      url = Micrate::DB.connection_url.to_s
      if url.starts_with? "sqlite3:"
        path = url.gsub("sqlite3:", "")
        File.delete(path)
        info "Deleted file #{path}"
      else
        name = set_database_to_schema url
        Micrate::DB.connect do |db|
          db.exec "DROP DATABASE IF EXISTS #{name};"
        end
        info "Dropped database #{name}"
      end
    end

    private def create_database
      url = Micrate::DB.connection_url.to_s
      if url.starts_with? "sqlite3:"
        info CREATE_SQLITE_MESSAGE
      else
        name = set_database_to_schema url
        Micrate::DB.connect do |db|
          db.exec "CREATE DATABASE #{name};"
        end
        info "Created database #{name}"
      end
    end

    private def set_database_to_schema(url) : String
      uri = URI.parse(url)
      if path = uri.path
        Micrate::DB.connection_url = url.gsub(path, "/#{uri.scheme}")
        return path.gsub("/", "")
      else
        error "Could not determine database name"
        exit!(error: true)
        return "" # This won't be reached but satisfies the compiler
      end
    end

    private def connect_to_database
      Process.exec(command_line_tool, {database_url}) if database_url
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

    private def database_url
      ENV["DATABASE_URL"]? || default_database_url
    end

    private def default_database_url
      # Try to read from config
      config_file = "config/database.cr"
      if File.exists?(config_file)
        # This is a simplified approach - in reality we'd need to parse the config
        # For now, return a default
        "postgres://localhost/amber_development"
      else
        "postgres://localhost/amber_development"
      end
    end
  end
end

# Register the command
AmberCLI::Core::CommandRegistry.register("database", ["db"], AmberCLI::Commands::DatabaseCommand)
