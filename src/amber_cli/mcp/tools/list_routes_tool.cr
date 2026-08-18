# :nodoc:
require "json"
require "../base_tool"
require "../application_inspector"
require "../../commands/routes"

module AmberCLI::MCP::Tools
  # Lists the routes declared in an application's `config/routes.cr`.
  class ListRoutesTool < AmberCLI::MCP::BaseTool
    def name : String
      "list_routes"
    end

    def title : String?
      "List application routes"
    end

    def description : String
      <<-TEXT
        List every route declared in an Amber application's config/routes.cr, with
        the HTTP verb, URI pattern, controller, action, pipeline and scope for each.
        Read-only; parses the routes file statically and never boots the
        application. Requires an absolute `path` to the application root.
        TEXT
    end

    def input_schema : ::MCProtocol::ToolInputSchema
      ::MCProtocol::ToolInputSchema.new(
        properties: JSON.parse({
          "path" => {
            "type"        => "string",
            "description" => "Absolute path to the application root directory.",
          },
          "filter" => {
            "type"        => "string",
            "description" => "Optional case-insensitive substring; only routes whose URI pattern or controller contains it are returned.",
          },
        }.to_json),
        required: ["path"]
      )
    end

    def call(arguments : Hash(String, JSON::Any)) : AmberCLI::MCP::ToolOutcome
      path = string_argument(arguments, "path")
      return AmberCLI::MCP::ToolOutcome.failure("`path` is required and must be a string.") unless path
      unless absolute_path?(path)
        return AmberCLI::MCP::ToolOutcome.failure("`path` must be absolute, got #{path.inspect}.")
      end

      inspector = AmberCLI::MCP::ApplicationInspector.new(path)
      unless File.exists?(inspector.routes_path)
        return AmberCLI::MCP::ToolOutcome.failure(
          "No routes file at #{inspector.routes_path}. Is #{inspector.path} an Amber application?"
        )
      end

      routes = collect_routes(inspector.routes_path)
      if filter = string_argument(arguments, "filter")
        needle = filter.downcase
        routes = routes.select do |route|
          route["URI Pattern"].downcase.includes?(needle) || route["Controller"].downcase.includes?(needle)
        end
      end

      payload = routes.map { |route| route.transform_keys(&.downcase.gsub(' ', '_')) }
      AmberCLI::MCP::ToolOutcome.data("#{payload.size} route(s) in #{inspector.path}", payload)
    rescue ex : File::Error
      AmberCLI::MCP::ToolOutcome.failure("Could not read routes: #{ex.message}")
    end

    # Reuses `RoutesCommand`'s parser rather than duplicating its regexes, driving
    # it with an explicit file path so nothing depends on the working directory.
    private def collect_routes(routes_file : String) : Array(Hash(String, String))
      command = AmberCLI::Commands::RoutesCommand.new("routes")
      command.parse_routes(routes_file)
      command.routes
    end
  end
end
