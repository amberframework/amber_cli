require "../core/base_command"

# The `pipelines` command displays and manages HTTP request pipelines
# configured in your Amber application.
#
# ## Usage
# ```
# amber pipelines [options]
# ```
#
# ## Options
# - `--json` - Output pipelines in JSON format
# - `--verbose` - Show detailed pipeline information
#
# ## Examples
# ```
# # Show all configured pipelines
# amber pipelines
#
# # Export pipeline configuration as JSON
# amber pipelines --json
#
# # Show detailed pipeline information
# amber pipelines --verbose
# ```
module AmberCLI::Commands
  class PipelinesCommand < AmberCLI::Core::BaseCommand
    getter result = Array(NamedTuple(pipes: Array(String), plugs: Array(String))).new
    getter show_plugs : Bool = true

    ROUTES_PATH          = "config/routes.cr"
    LABELS               = %w(Pipeline Pipe)
    LABELS_WITHOUT_PLUGS = %w(Pipeline)

    PIPELINE_REGEX =
      /^
        \s*
        pipeline  # match pipeline
        \s+       # require at least one whitespace character after pipeline
        (
          (?:
            (?:
              \:(?:\w+)
              |
              \"(?:\w+)\"
            )
            (?:\,\s*)?
          )+
        )         # match and capture all contiguous words
      /x

    PLUG_REGEX =
      /^
        \s*
        plug        # match plug
        \s+         # require at least one whitespace character after plug
        (
          [\w:]+    # match at least one words with maybe a colon
        )?
        (?:
          [\.\s*\(] # until we reach ., spaces, or braces
        )?
      /x

    FAILED_TO_PARSE_ERROR = "Could not parse pipeline/plugs in #{ROUTES_PATH}"

    def help_description : String
      "Shows all defined pipelines and their associated plugs"
    end

    def setup_command_options
      option_parser.on("--no-plugs", "Don't output the plugs") do
        @parsed_options["no_plugs"] = true
        @show_plugs = false
      end

      option_parser.separator ""
      option_parser.separator "Usage: amber pipelines [options]"
      option_parser.separator ""
      option_parser.separator "Examples:"
      option_parser.separator "  amber pipelines"
      option_parser.separator "  amber pipelines --no-plugs"
    end

    def execute
      parse_routes
      print_pipelines
    rescue ex
      if ex.message && ex.message.not_nil!.includes?("Could not parse")
        error ex.message.not_nil!
        exit!(error: true)
      else
        error "Not valid project root directory."
        info "Run `amber pipelines` in project root directory."
        exit!(error: true)
      end
    end

    private def parse_routes
      unless File.exists?(ROUTES_PATH)
        error "Routes file not found: #{ROUTES_PATH}"
        exit!(error: true)
      end

      lines = File.read_lines(ROUTES_PATH)

      lines.map(&.strip).each do |line|
        case line
        when .starts_with?("pipeline") then set_pipe(line)
        when .starts_with?("plug")     then set_plug(line)
        else
          # skip line
        end
      end
    end

    private def set_pipe(line)
      match = line.match(PIPELINE_REGEX)

      if match && (pipes = match[1])
        pipes = pipes.split(/,\s*/).map(&.gsub(/[:\"]/, ""))
        result << {pipes: pipes, plugs: [] of String}
      else
        error FAILED_TO_PARSE_ERROR
        exit!(error: true)
      end
    end

    private def set_plug(line)
      match = line.match(PLUG_REGEX)

      if match && (plug = match[1]) && result.last
        result.last[:plugs] << plug
      else
        error FAILED_TO_PARSE_ERROR
        exit!(error: true)
      end
    end

    private def print_pipelines
      return if result.empty?

      if show_plugs
        print_pipelines_with_plugs
      else
        print_pipelines_only
      end
    end

    private def print_pipelines_with_plugs
      # Calculate column widths
      pipeline_width = LABELS[0].size
      plug_width = LABELS[1].size

      result.each do |pipes_and_plugs|
        pipes_and_plugs[:pipes].each do |pipe|
          pipeline_width = [pipeline_width, pipe.size].max
          pipes_and_plugs[:plugs].each do |plug|
            plug_width = [plug_width, plug.size].max
          end
        end
      end

      column_widths = [pipeline_width, plug_width]

      # Print header
      print_table_separator(column_widths)
      print_table_row(LABELS, column_widths, header: true)
      print_table_separator(column_widths)

      # Print pipelines and plugs
      result.each do |pipes_and_plugs|
        pipes_and_plugs[:pipes].each do |pipe|
          if pipes_and_plugs[:plugs].empty?
            print_table_row([pipe, ""], column_widths)
          else
            pipes_and_plugs[:plugs].each do |plug|
              print_table_row([pipe, plug], column_widths)
            end
          end
        end
      end

      print_table_separator(column_widths)
    end

    private def print_pipelines_only
      # Get unique pipelines
      pipelines = result.flat_map { |pipes_and_plugs| pipes_and_plugs[:pipes] }.uniq!

      # Calculate column width
      pipeline_width = [LABELS_WITHOUT_PLUGS[0].size, pipelines.map(&.size).max? || 0].max
      column_widths = [pipeline_width]

      # Print header
      print_table_separator(column_widths)
      print_table_row(LABELS_WITHOUT_PLUGS, column_widths, header: true)
      print_table_separator(column_widths)

      # Print pipelines
      pipelines.each do |pipeline|
        print_table_row([pipeline], column_widths)
      end

      print_table_separator(column_widths)
    end

    private def print_table_separator(column_widths)
      separator = "+"
      column_widths.each do |width|
        separator += "-" * (width + 2) + "+"
      end
      puts separator
    end

    private def print_table_row(values, column_widths, header = false)
      row = "| "
      values.each_with_index do |value, index|
        formatted_value = value.ljust(column_widths[index])
        if header && !no_color?
          formatted_value = formatted_value.colorize.light_red.to_s
        end
        row += formatted_value + " | "
      end
      puts row
    end
  end
end

# Register the command
AmberCLI::Core::CommandRegistry.register("pipelines", ["pipes"], AmberCLI::Commands::PipelinesCommand)
