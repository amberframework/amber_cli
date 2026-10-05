# :nodoc:
require "json"
require "../base_tool"
require "../application_inspector"

module AmberCLI::MCP::Tools
  # Reports whether a directory holds an Amber application, and what kind.
  class ProjectInfoTool < AmberCLI::MCP::BaseTool
    def name : String
      "project_info"
    end

    def title : String?
      "Inspect an Amber project"
    end

    def description : String
      <<-TEXT
        Inspect a directory and report whether it is an Amber application, which
        Amber version it depends on, its database adapter, template language, and
        the key files present. Read-only; writes nothing. Requires an absolute
        `path` to the application root — this server never infers a project from its
        own working directory.
        TEXT
    end

    def input_schema : ::MCProtocol::ToolInputSchema
      ::MCProtocol::ToolInputSchema.new(
        properties: JSON.parse({
          "path" => {
            "type"        => "string",
            "description" => "Absolute path to the application root directory.",
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
      unless inspector.exists?
        return AmberCLI::MCP::ToolOutcome.failure("No such directory: #{inspector.path}")
      end

      summary =
        if inspector.amber_application?
          "#{inspector.application_name || File.basename(inspector.path)} is an Amber application."
        else
          "#{inspector.path} exists but does not look like an Amber application."
        end

      AmberCLI::MCP::ToolOutcome.data(summary, inspector.to_json_payload)
    end
  end
end
