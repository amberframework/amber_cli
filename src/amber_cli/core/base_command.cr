require "option_parser"

module AmberCLI::Core
  abstract class BaseCommand
    getter command_name : String
    getter option_parser : OptionParser
    getter parsed_options : Hash(String, String | Bool | Array(String))
    getter remaining_arguments : Array(String)

    def initialize(@command_name : String)
      @option_parser = OptionParser.new
      @parsed_options = Hash(String, String | Bool | Array(String)).new
      @remaining_arguments = Array(String).new
      setup_options
    end

    abstract def setup_options
    abstract def run(args : Array(String)) : Int32

    def parse_arguments(args : Array(String)) : Array(String)
      remaining = @option_parser.parse(args)
      @remaining_arguments = remaining || Array(String).new
      remaining || Array(String).new
    end

    def has_option?(key : String) : Bool
      @parsed_options.has_key?(key)
    end

    def option_value(key : String)
      @parsed_options[key]?
    end

    def show_help(io : IO = STDOUT)
      @option_parser.to_s(io)
    end
  end

  class CommandRegistry
    @commands : Hash(String, BaseCommand)

    def initialize
      @commands = Hash(String, BaseCommand).new
    end

    def register_command(command : BaseCommand)
      @commands[command.command_name] = command
    end

    def has_command?(name : String) : Bool
      @commands.has_key?(name)
    end

    def run_command(name : String, args : Array(String)) : Int32
      return 1 unless has_command?(name)
      
      command = @commands[name]
      begin
        command.parse_arguments(args)
        command.run(command.remaining_arguments)
      rescue
        1
      end
    end

    def list_commands : Array(String)
      @commands.keys.sort
    end
  end
end 