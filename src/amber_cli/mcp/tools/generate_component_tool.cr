# :nodoc:
require "json"
require "../base_tool"
require "../cli_runner"
require "../application_inspector"
require "../../commands/generate"

module AmberCLI::MCP::Tools
  # Runs an Amber generator inside an existing application. **Writes to the filesystem.**
  class GenerateComponentTool < AmberCLI::MCP::BaseTool
    getter runner : AmberCLI::MCP::CliRunner

    def initialize(@runner : AmberCLI::MCP::CliRunner = AmberCLI::MCP::CliRunner.new)
    end

    def name : String
      "generate_component"
    end

    def title : String?
      "Generate an Amber component"
    end

    def description : String
      <<-TEXT
        MUTATING: runs an Amber generator inside an existing application, writing
        new source files (and, for some generators, migrations and specs) under the
        given path. Existing files may be overwritten by the generator. Requires an
        absolute `path` to an Amber application root, a generator `type`, and a
        component `name`. Call `list_generators` for the available types and their
        arguments. Runs non-interactively.
        TEXT
    end

    def mutating? : Bool
      true
    end

    def input_schema : ::MCProtocol::ToolInputSchema
      ::MCProtocol::ToolInputSchema.new(
        properties: JSON.parse({
          "path" => {
            "type"        => "string",
            "description" => "Absolute path to the Amber application root.",
          },
          "type" => {
            "type"        => "string",
            "enum"        => AmberCLI::Commands::GenerateCommand::VALID_TYPES,
            "description" => "Generator to run.",
          },
          "name" => {
            "type"        => "string",
            "description" => "Name of the component to generate, e.g. \"User\" or \"Posts\".",
          },
          "fields" => {
            "type"        => "array",
            "items"       => {"type" => "string"},
            "description" => "Field or action arguments, e.g. [\"title:string\", \"body:text\"] for a model, or [\"index\", \"show\"] for a controller.",
          },
        }.to_json),
        required: ["path", "type", "name"]
      )
    end

    def call(arguments : Hash(String, JSON::Any)) : AmberCLI::MCP::ToolOutcome
      path = string_argument(arguments, "path")
      return AmberCLI::MCP::ToolOutcome.failure("`path` is required and must be a string.") unless path
      unless absolute_path?(path)
        return AmberCLI::MCP::ToolOutcome.failure("`path` must be absolute, got #{path.inspect}.")
      end

      generator_type = string_argument(arguments, "type")
      return AmberCLI::MCP::ToolOutcome.failure("`type` is required and must be a string.") unless generator_type

      unless AmberCLI::Commands::GenerateCommand::VALID_TYPES.includes?(generator_type)
        return AmberCLI::MCP::ToolOutcome.failure(
          "Unknown generator #{generator_type.inspect}. Available: " \
          "#{AmberCLI::Commands::GenerateCommand::VALID_TYPES.join(", ")}"
        )
      end

      component_name = string_argument(arguments, "name")
      return AmberCLI::MCP::ToolOutcome.failure("`name` is required and must be a string.") unless component_name
      if component_name.blank? || component_name.matches?(/\s/)
        return AmberCLI::MCP::ToolOutcome.failure("`name` must be a single non-blank token, got #{component_name.inspect}.")
      end

      inspector = AmberCLI::MCP::ApplicationInspector.new(path)
      unless inspector.exists?
        return AmberCLI::MCP::ToolOutcome.failure("No such directory: #{inspector.path}")
      end
      unless inspector.amber_application?
        return AmberCLI::MCP::ToolOutcome.failure(
          "#{inspector.path} does not look like an Amber application " \
          "(no .amber.yml and no amber dependency in shard.yml). Refusing to generate into it."
        )
      end

      run(inspector.path, generator_type, component_name, string_list_argument(arguments, "fields"))
    end

    private def run(app_path : String, generator_type : String, component_name : String, fields : Array(String)) : AmberCLI::MCP::ToolOutcome
      args = ["generate", generator_type, component_name] + fields
      outcome = @runner.run(args, chdir: app_path)

      if outcome.timed_out?
        return AmberCLI::MCP::ToolOutcome.failure(
          "amber #{args.join(' ')} timed out and was killed. Partial output:\n#{outcome.combined_output}"
        )
      end

      unless outcome.success?
        return AmberCLI::MCP::ToolOutcome.failure(
          "amber #{args.join(' ')} failed with exit code #{outcome.exit_code}:\n#{outcome.combined_output}"
        )
      end

      AmberCLI::MCP::ToolOutcome.data(
        "Generated #{generator_type} #{component_name} in #{app_path}",
        {
          "path"    => app_path,
          "type"    => generator_type,
          "name"    => component_name,
          "fields"  => fields,
          "command" => "amber #{args.join(' ')}",
          "output"  => outcome.combined_output,
        }
      )
    end
  end
end
