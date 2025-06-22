# :nodoc:
require "./core/base_command"

module AmberCLI
  class MainCommand < AmberCLI::Core::BaseCommand
    def initialize
      super("amber")
    end

    def help_description : String
      "Amber CLI - Crystal web framework tool"
    end

    def setup_command_options
      option_parser.banner = "Usage: amber [command] [options]"

      option_parser.on("--version", "Show version") do
        puts "Amber CLI #{VERSION}"
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

    def execute
      if remaining_arguments.empty?
        puts option_parser
        return
      end

      command = remaining_arguments[0]
      command_args = remaining_arguments[1..]

      Core::CommandRegistry.execute_command(command, command_args)
    end

    def self.run(args : Array(String))
      command = new
      command.parse_and_execute(args)
    end
  end
end
