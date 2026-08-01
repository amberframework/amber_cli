# :nodoc:
require "json"
require "../base_tool"
require "../document_index"

module AmberCLI::MCP::Tools
  # Reads one bundled documentation file in full.
  class ReadDocTool < AmberCLI::MCP::BaseTool
    def name : String
      "read_doc"
    end

    def title : String?
      "Read an Amber documentation file"
    end

    def description : String
      <<-TEXT
        Read one documentation file bundled into this Amber CLI binary, by id.
        Read-only. Call with no `id` to list every available document. Ids are
        repository-relative paths such as "README.md" or "docs/GENERATOR_SUPPORT.md";
        `search_docs` returns the id of every match.
        TEXT
    end

    def input_schema : ::MCProtocol::ToolInputSchema
      ::MCProtocol::ToolInputSchema.new(
        properties: JSON.parse({
          "id" => {
            "type"        => "string",
            "enum"        => AmberCLI::MCP::DocumentIndex.ids,
            "description" => "Document id to read. Omit to list the available documents.",
          },
        }.to_json),
        required: [] of String
      )
    end

    def call(arguments : Hash(String, JSON::Any)) : AmberCLI::MCP::ToolOutcome
      id = string_argument(arguments, "id")
      return catalog_outcome unless id

      body = AmberCLI::MCP::DocumentIndex.document?(id)
      unless body
        return AmberCLI::MCP::ToolOutcome.failure(
          "Unknown document #{id.inspect}. Available: #{AmberCLI::MCP::DocumentIndex.ids.join(", ")}"
        )
      end

      AmberCLI::MCP::ToolOutcome.new(body, JSON.parse({"id" => id, "content" => body}.to_json))
    end

    private def catalog_outcome : AmberCLI::MCP::ToolOutcome
      catalog = AmberCLI::MCP::DocumentIndex.catalog
      AmberCLI::MCP::ToolOutcome.data("#{catalog.size} documents available", catalog)
    end
  end
end
