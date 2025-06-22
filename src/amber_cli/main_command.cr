require "./core/base_command"

module AmberCLI
  class MainCommand < AmberCLI::Core::BaseCommand
    def initialize
      super("amber")
    end

    def setup_options
      option_parser.banner = "Usage: amber [command] [options]"

      option_parser.on("--version", "Show version") do
        puts "Amber CLI #{AmberCli::VERSION}"
        puts "Targets Amber Framework #{Amber::VERSION}"
        exit 0
      end

      option_parser.on("-h", "--help", "Show help") do
        puts option_parser
        exit 0
      end

      option_parser.separator ""
      option_parser.separator "Commands:"
      option_parser.separator "  new [name]            Create a new Amber application"
      option_parser.separator "  generate [type] [name] Generate components (model, controller, etc.)"
      option_parser.separator "  routes                Show all routes"
      option_parser.separator "  watch                 Watch and reload application"
      option_parser.separator "  exec [command]        Execute commands in the context of the application"
      option_parser.separator "  database [command]    Database migration and seeding tasks"
      option_parser.separator "  encrypt [command]     Encryption utilities"
      option_parser.separator "  pipelines             Pipeline management"
      option_parser.separator "  plugin [command]      Plugin management"
      option_parser.separator ""
      option_parser.separator "Use 'amber [command] --help' for more information on a specific command."
    end

    def run(args : Array(String)) : Int32
      if args.empty?
        puts option_parser
        return 0
      end

      command = args[0]
      remaining_args = args[1..]

      case command
      when "new"
        puts "Creating new Amber application..."
        # TODO: Implement new command
        return 0
      when "generate"
        puts "Generating components..."
        # TODO: Implement generate command
        return 0
      when "routes"
        puts "Showing routes..."
        # TODO: Implement routes command
        return 0
      when "watch"
        puts "Starting watch mode..."
        # TODO: Implement watch command
        return 0
      when "exec"
        puts "Executing command..."
        # TODO: Implement exec command
        return 0
      when "database"
        puts "Database operations..."
        # TODO: Implement database command
        return 0
      when "encrypt"
        puts "Encryption utilities..."
        # TODO: Implement encrypt command
        return 0
      when "pipelines"
        puts "Pipeline management..."
        # TODO: Implement pipelines command
        return 0
      when "plugin"
        puts "Plugin management..."
        # TODO: Implement plugin command
        return 0
      else
        puts "Unknown command: #{command}"
        puts option_parser
        return 1
      end
    end

    def self.run(args : Array(String))
      command = new
      exit_code = command.run(args)
      exit exit_code
    end
  end
end
