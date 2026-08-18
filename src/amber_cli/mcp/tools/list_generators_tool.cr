# :nodoc:
require "json"
require "../base_tool"
require "../../commands/generate"

module AmberCLI::MCP::Tools
  # Enumerates the generators `generate_component` can invoke.
  class ListGeneratorsTool < AmberCLI::MCP::BaseTool
    # What each generator produces, keyed by the type `amber generate` accepts.
    GENERATOR_SUMMARIES = {
      "model"      => "A model class plus its migration.",
      "controller" => "A controller with the named actions, its views and a spec.",
      "scaffold"   => "A full CRUD resource: model, schema, controller, views, migration.",
      "migration"  => "An empty migration file.",
      "mailer"     => "A mailer class (Amber::Mailer::Base).",
      "job"        => "A background job class (Amber::Jobs::Job).",
      "schema"     => "A schema definition (Amber::Schema::Definition).",
      "channel"    => "A WebSocket channel (Amber::WebSockets::Channel).",
      "api"        => "An API-only controller with its model.",
      "auth"       => "An authentication system.",
    }

    # Options that apply to specific generators only.
    GENERATOR_OPTIONS = {
      "job"        => ["--queue=QUEUE", "--max-retries=N"],
      "mailer"     => ["--actions=a,b"],
      "controller" => ["positional action names, e.g. index show create"],
      "channel"    => ["--topics=a,b"],
    }

    def name : String
      "list_generators"
    end

    def title : String?
      "List available generators"
    end

    def description : String
      <<-TEXT
        List every generator `generate_component` can run, with what each produces,
        the arguments it accepts, and whether it is a stable or preview surface in
        this beta. Read-only; takes no arguments and touches no files.
        TEXT
    end

    def input_schema : ::MCProtocol::ToolInputSchema
      ::MCProtocol::ToolInputSchema.new(
        properties: JSON.parse("{}"),
        required: [] of String
      )
    end

    def call(arguments : Hash(String, JSON::Any)) : AmberCLI::MCP::ToolOutcome
      generators = AmberCLI::Commands::GenerateCommand::VALID_TYPES.map do |type|
        {
          "type"        => type,
          "summary"     => GENERATOR_SUMMARIES[type]? || "",
          "preview"     => AmberCLI::Commands::GenerateCommand::PREVIEW_TYPES.includes?(type),
          "options"     => GENERATOR_OPTIONS[type]? || [] of String,
          "fieldFormat" => "name:type[:required]",
        }
      end

      payload = {
        "generators" => generators,
        "fieldTypes" => AmberCLI::Commands::GenerateCommand::FIELD_TYPE_MAP.keys.to_a,
      }

      AmberCLI::MCP::ToolOutcome.data("#{generators.size} generators available", payload)
    end
  end
end
