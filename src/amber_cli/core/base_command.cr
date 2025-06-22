require "option_parser"

module AmberCLI::Core
  abstract class BaseCommand
    getter option_parser : OptionParser
    getter parsed_options : Hash(String, String | Bool | Array(String))
    getter remaining_arguments : Array(String)

    def initialize(@command_name : String)
      @option_parser = OptionParser.new
      @parsed_options = Hash(String, String | Bool | Array(String)).new
      @remaining_arguments = Array(String).new
      setup_global_options
      setup_command_options
    end

    abstract def setup_command_options
    abstract def execute
    abstract def help_description : String

    private def setup_global_options
      option_parser.banner = help_description
      option_parser.on("--no-color", "Disable colored output") do
        @parsed_options["no_color"] = true
      end
      option_parser.on("-h", "--help", "Show help") do
        puts option_parser
        exit(0)
      end
    end

    def parse_and_execute(args : Array(String))
      option_parser.unknown_args do |unknown_args, _|
        @remaining_arguments.concat(unknown_args)
      end

      option_parser.parse(args)
      validate_arguments
      execute
    rescue ex : OptionParser::InvalidOption
      error "Invalid option: #{ex.message}"
      puts option_parser
      exit(1)
    end

    protected def validate_arguments
      # Override in subclasses for specific validation
    end

    protected def error(message : String)
      puts "Error: #{message}".colorize.red
    end

    protected def info(message : String)
      puts message.colorize.light_cyan
    end

    protected def success(message : String)
      puts message.colorize.green
    end

    protected def warning(message : String)
      puts message.colorize.yellow
    end

    protected def no_color?
      @parsed_options["no_color"]? == true
    end

    protected def exit!(message : String = "", error : Bool = false)
      puts message unless message.empty?
      exit(error ? 1 : 0)
    end
  end

  class CommandRegistry
    COMMANDS = {} of String => BaseCommand.class

    def self.register(name : String, aliases : Array(String), command_class : BaseCommand.class)
      COMMANDS[name] = command_class
      aliases.each { |alias_name| COMMANDS[alias_name] = command_class }
    end

    def self.find_command(name : String)
      COMMANDS[name]?
    end

    def self.list_commands : Array(String)
      COMMANDS.keys.uniq
    end

    def self.execute_command(command_name : String, args : Array(String))
      if command_class = find_command(command_name)
        command = command_class.new(command_name)
        command.parse_and_execute(args)
      else
        puts "Unknown command: #{command_name}"
        show_help
        exit(1)
      end
    end

    private def self.show_help
      puts <<-HELP
      Amber CLI - Crystal web framework tool

      Available commands:
      #{list_commands.join(", ")}

      Use 'amber <command> --help' for more information about a command.
      HELP
    end
  end
end
