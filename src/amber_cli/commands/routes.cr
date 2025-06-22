require "../core/base_command"
require "json"
require "../helpers/helpers"

# The `routes` command displays all defined routes in your Amber application.
#
# ## Usage
# ```
# amber routes [options]
# ```
#
# ## Options
# - `--json` - Output routes in JSON format
# - `--filter` - Filter routes by pattern
#
# ## Examples
# ```
# # Show all routes in table format
# amber routes
#
# # Export routes as JSON
# amber routes --json
#
# # Filter routes containing "api"
# amber routes --filter api
# ```
module AmberCLI::Commands
  class RoutesCommand < AmberCLI::Core::BaseCommand
    RESOURCE_ROUTE_REGEX  = /(\w+)\s+\"([^\"]+)\",\s*([\w:]+)(?:,\s*(\w+)\:\s*\[([^\]]+)\])?/
    VERB_ROUTE_REGEX      = /(\w+)\s+\"([^\"]+)\",\s*([\w:]+),\s*:(\w+)/
    WEBSOCKET_ROUTE_REGEX = /(websocket)\s+\"([^\"]+)\",\s*([\w:]+)/
    PIPE_SCOPE_REGEX      = /(routes)\s+\:(\w+)(?:,\s+\"([^\"]+)\")?/

    LABELS         = ["Verb", "Controller", "Action", "Pipeline", "Scope", "URI Pattern"]
    ACTION_MAPPING = {
      "get"    => ["index", "show", "new", "edit"],
      "post"   => ["create"],
      "patch"  => ["update"],
      "put"    => ["update"],
      "delete" => ["destroy"],
    }

    getter routes = Array(Hash(String, String)).new
    property current_pipe : String?
    property current_scope : String?
    getter json_output : Bool = false

    def help_description : String
      "Prints all defined application routes"
    end

    def setup_command_options
      option_parser.on("--json", "Display routes as JSON") do
        @parsed_options["json"] = true
        @json_output = true
      end

      option_parser.separator ""
      option_parser.separator "Usage: amber routes [options]"
      option_parser.separator ""
      option_parser.separator "Examples:"
      option_parser.separator "  amber routes"
      option_parser.separator "  amber routes --json"
    end

    def execute
      parse_routes
      if json_output
        print_routes_json
      else
        print_routes_table
      end
    rescue
      error "Not valid project root directory."
      info "Run `amber routes` in project root directory."
      exit!(error: true)
    end

    private def parse_routes
      File.read_lines("config/routes.cr").each do |line|
        case line.strip
        when .starts_with?("routes")
          set_pipe(line)
        when .starts_with?("resources")
          set_resources(line)
        else
          set_route(line)
        end
      end
    end

    private def set_route(route_string)
      return if route_string.to_s.lstrip.starts_with?("#")
      if route_match = route_string.to_s.match(VERB_ROUTE_REGEX)
        return unless ACTION_MAPPING.keys.includes?(route_match[1]?.to_s)
        build_route(route_match)
      elsif route_match = route_string.to_s.match(WEBSOCKET_ROUTE_REGEX)
        build_route(route_match)
      end
    end

    private def set_resources(resource_string)
      if route_match = resource_string.to_s.match(RESOURCE_ROUTE_REGEX)
        filter = route_match[4]?
        filter_actions = route_match[5]?.to_s.gsub(/\:|\s/, "").split(",")
        ACTION_MAPPING.each do |verb, v|
          v.each do |action|
            case filter
            when "only"
              next unless filter_actions.includes?(action)
            when "except"
              next if filter_actions.includes?(action)
            else
              build_route(
                verb: verb, controller: route_match[3]?, action: action,
                pipeline: current_pipe, scope: current_scope,
                uri_pattern: build_uri_pattern(route_match[2]?, action, current_scope)
              )
            end
          end
        end
      end
    end

    def build_route(verb, uri_pattern, controller, action, pipeline, scope = "")
      route = {"Verb" => verb.to_s}
      route["URI Pattern"] = uri_pattern.to_s
      route["Controller"] = controller.to_s
      route["Action"] = action.to_s
      route["Pipeline"] = pipeline.to_s
      route["Scope"] = scope.to_s
      routes << route
    end

    private def build_route(route_match)
      build_route(
        verb: route_match[1]?, controller: route_match[3]?,
        action: route_match[4]? || "", pipeline: current_pipe,
        scope: current_scope, uri_pattern: route_match[2]?
      )
    end

    private def build_uri_pattern(route, action, scope)
      route_end = {"show" => ":id", "new" => "new", "edit" => ":id/edit", "update" => ":id", "destroy" => ":id"}
      [scope, route, route_end[action]?].compact.join("/").gsub("//", "/")
    end

    private def set_pipe(pipe_string)
      if route_match = pipe_string.to_s.match(PIPE_SCOPE_REGEX)
        @current_pipe = route_match[2]?
        @current_scope = route_match[3]?
      end
    end

    private def print_routes_json
      json_routes = routes.map { |route|
        route.transform_keys(&.to_s.downcase.gsub(' ', '_'))
      }
      puts json_routes.to_json
    end

    private def print_routes_table
      return if routes.empty?

      # Calculate column widths
      column_widths = LABELS.map { |label| label.size }
      routes.each do |route|
        LABELS.each_with_index do |label, index|
          column_widths[index] = [column_widths[index], route[label].size].max
        end
      end

      # Print header
      print_table_separator(column_widths)
      print_table_row(LABELS, column_widths, header: true)
      print_table_separator(column_widths)

      # Print routes
      routes.each do |route|
        values = LABELS.map { |label| route[label] }
        print_table_row(values, column_widths)
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
AmberCLI::Core::CommandRegistry.register("routes", ["r"], AmberCLI::Commands::RoutesCommand)
