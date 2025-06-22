require "log"
require "./version"
require "./exceptions/*"
require "./environment"

# New core architecture modules
require "./amber_cli/exceptions"
require "./amber_cli/core/word_transformer"
require "./amber_cli/core/generator_config"
require "./amber_cli/core/template_engine"
require "./amber_cli/core/base_command"
require "./amber_cli/core/configurable_generator_manager"

# Include comprehensive documentation for crystal docs generation
require "./amber_cli/documentation"

# Load all commands - they will register themselves
require "./amber_cli/commands/new"
require "./amber_cli/commands/database"
require "./amber_cli/commands/routes"
require "./amber_cli/commands/watch"
require "./amber_cli/commands/encrypt"
require "./amber_cli/commands/exec"
require "./amber_cli/commands/plugin"
require "./amber_cli/commands/pipelines"

backend = Log::IOBackend.new
backend.formatter = Log::Formatter.new do |entry, io|
  io << entry.timestamp.to_s("%I:%M:%S")
  io << " "
  io << entry.source
  io << " (#{entry.severity})" if entry.severity > Log::Severity::Debug
  io << " "
  io << entry.message
end
Log.builder.bind "*", :info, backend

module AmberCLI
  VERSION = "2.0.0"

  def self.run(args = ARGV)
    if args.empty?
      show_help
      return
    end

    command_name = args[0]
    command_args = args[1..]

    Core::CommandRegistry.execute_command(command_name, command_args)
  end

  private def self.show_help
    puts <<-HELP
    Amber CLI v#{VERSION} - Crystal web framework tool

    Usage: amber <command> [options]

    Available commands:
      new (n)        Create a new Amber application
      database (db)  Database operations and migrations
      routes (r)     Display application routes
      watch (w)      Start development server with file watching
      encrypt (e)    Encrypt/decrypt environment files
      exec (x)       Execute Crystal code in application context
      plugin (pl)    Generate application plugins
      pipelines      Show application pipelines and plugs

    Use 'amber <command> --help' for more information about a command.
    HELP
  end
end

# Run the CLI if this is the main file
AmberCLI.run if PROGRAM_NAME.includes?("amber")
