# :nodoc:
require "json"
require "../base_tool"
require "../cli_runner"
require "../../commands/new"

module AmberCLI::MCP::Tools
  # Scaffolds a new Amber application. **Writes to the filesystem.**
  class CreateNewAppTool < AmberCLI::MCP::BaseTool
    getter runner : AmberCLI::MCP::CliRunner

    def initialize(@runner : AmberCLI::MCP::CliRunner = AmberCLI::MCP::CliRunner.new)
    end

    def name : String
      "create_new_app"
    end

    def title : String?
      "Create a new Amber application"
    end

    def description : String
      <<-TEXT
        MUTATING: creates a new Amber application on disk, writing a full project
        tree (src/, config/, db/, spec/, public/, shard.yml, .amber.yml) at the
        given path. Requires an absolute `path` whose parent directory exists and
        whose final component does NOT already exist — this tool refuses to write
        into an existing directory rather than merging into it. Runs
        non-interactively. Dependency installation is skipped unless
        `install_dependencies` is true, because `shards install` needs the network
        and can take minutes.
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
            "description" => "Absolute path of the application directory to create. Must not already exist.",
          },
          "database" => {
            "type"        => "string",
            "enum"        => AmberCLI::Commands::NewCommand::VALID_DATABASES,
            "description" => "Database engine to record. Defaults to pg.",
          },
          "type" => {
            "type"        => "string",
            "enum"        => AmberCLI::Commands::NewCommand::VALID_APP_TYPES,
            "description" => "Application type. Defaults to web; native is a preview surface.",
          },
          "install_dependencies" => {
            "type"        => "boolean",
            "description" => "Run shards install after scaffolding. Defaults to false.",
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

      target = File.expand_path(path)
      if File.exists?(target) || Dir.exists?(target)
        return AmberCLI::MCP::ToolOutcome.failure(
          "Refusing to scaffold into an existing path: #{target} already exists. " \
          "Choose a path that does not exist yet."
        )
      end

      parent = File.dirname(target)
      unless Dir.exists?(parent)
        return AmberCLI::MCP::ToolOutcome.failure("Parent directory does not exist: #{parent}")
      end

      project_name = File.basename(target)
      if project_name.matches?(/\s/)
        return AmberCLI::MCP::ToolOutcome.failure("Project name must not contain whitespace: #{project_name.inspect}")
      end

      if error = validate_choice(arguments, "database", AmberCLI::Commands::NewCommand::VALID_DATABASES)
        return error
      end
      if error = validate_choice(arguments, "type", AmberCLI::Commands::NewCommand::VALID_APP_TYPES)
        return error
      end

      run(arguments, parent, project_name, target)
    end

    private def run(arguments, parent : String, project_name : String, target : String) : AmberCLI::MCP::ToolOutcome
      args = ["new", project_name, "--assume-yes"]
      if database = string_argument(arguments, "database")
        args << "--database=#{database}"
      end
      if app_type = string_argument(arguments, "type")
        args << "--type=#{app_type}"
      end
      args << "--no-deps" unless arguments["install_dependencies"]?.try(&.as_bool?)

      outcome = @runner.run(args, chdir: parent)

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
        "Created #{project_name} at #{target}",
        {
          "path"    => target,
          "name"    => project_name,
          "command" => "amber #{args.join(' ')}",
          "output"  => outcome.combined_output,
        }
      )
    end

    private def validate_choice(arguments, key : String, allowed : Array(String)) : AmberCLI::MCP::ToolOutcome?
      value = string_argument(arguments, key)
      return if value.nil? || allowed.includes?(value)

      AmberCLI::MCP::ToolOutcome.failure("Invalid `#{key}` #{value.inspect}. Allowed: #{allowed.join(", ")}")
    end
  end
end
