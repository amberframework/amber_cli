module AmberLSP::LibraryLint
  # Parses and validates arguments for `amber-lsp check`.
  class ParseLibraryLintCheckOptions
    USAGE = "Usage: amber-lsp check [--since REF] [--all] [--carried-in PATH]... [--format text|json|github] [--advisory] [--root DIR] [PATH...]"

    # Initializes the parser with command arguments.
    def initialize(@list_of_arguments : Array(String))
      @since_reference = ""
      @root_path = Dir.current
      @format = "text"
      @list_of_paths = [] of String
      @list_of_carried_in_paths = [] of String
      @all = false
      @advisory = false
      @has_explicit_paths = false
    end

    # Parses arguments and returns the validated options.
    def perform : Options
      argument_index = 0
      while argument_index < @list_of_arguments.size
        argument_index = parse_argument(argument_index) + 1
      end

      validate_arguments
      @list_of_paths = %w[src spec] if @list_of_paths.empty?
      Options.new(
        @root_path,
        @since_reference,
        @format,
        @list_of_paths,
        @list_of_carried_in_paths,
        @all,
        @advisory,
        @has_explicit_paths,
      )
    end

    private def parse_argument(argument_index : Int32) : Int32
      current_argument = @list_of_arguments[argument_index]
      case current_argument
      when "--since"
        @since_reference = option_value(argument_index, "--since requires a REF")
        argument_index + 1
      when "--all"
        @all = true
        argument_index
      when "--carried-in"
        @list_of_carried_in_paths << option_value(argument_index, "--carried-in requires a PATH")
        argument_index + 1
      when "--format"
        @format = option_value(argument_index, "--format requires text, json, or github")
        unless @format.in?(%w[text json github])
          raise InvalidArguments.new("--format supports text, json, or github")
        end
        argument_index + 1
      when "--advisory"
        @advisory = true
        argument_index
      when "--root"
        @root_path = option_value(argument_index, "--root requires a DIR")
        argument_index + 1
      else
        add_path_argument(current_argument)
        argument_index
      end
    end

    private def option_value(argument_index : Int32, error_message : String) : String
      option_value = @list_of_arguments[argument_index + 1]?
      if option_value.nil? || option_value.starts_with?("--")
        raise InvalidArguments.new(error_message)
      end

      option_value
    end

    private def add_path_argument(path_argument : String) : Nil
      if path_argument.starts_with?('-')
        raise InvalidArguments.new("Unknown option `#{path_argument}`")
      end

      @has_explicit_paths = true
      @list_of_paths << path_argument
    end

    private def validate_arguments : Nil
      if @all && !@since_reference.empty?
        raise InvalidArguments.new("--all and --since cannot be combined")
      end
      if !@all && @since_reference.empty?
        raise InvalidArguments.new("Provide --since REF or --all")
      end
    end
  end
end
