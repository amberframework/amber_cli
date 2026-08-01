# :nodoc:
require "json"
require "../base_tool"
require "../document_index"

module AmberCLI::MCP::Tools
  # Full-text search across the CLI's bundled documentation.
  class SearchDocsTool < AmberCLI::MCP::BaseTool
    def name : String
      "search_docs"
    end

    def title : String?
      "Search Amber documentation"
    end

    def description : String
      <<-TEXT
        Search the Amber CLI documentation bundled into this binary for a
        case-insensitive substring, returning each match with its document id, line
        number and surrounding context. Read-only. Pass a matching document id to
        `read_doc` to read the full text.
        TEXT
    end

    def input_schema : ::MCProtocol::ToolInputSchema
      ::MCProtocol::ToolInputSchema.new(
        properties: JSON.parse({
          "query" => {
            "type"        => "string",
            "description" => "Case-insensitive substring to search for.",
          },
          "limit" => {
            "type"        => "integer",
            "minimum"     => 1,
            "maximum"     => AmberCLI::MCP::DocumentIndex::DEFAULT_MATCH_LIMIT,
            "description" => "Maximum number of matches to return.",
          },
        }.to_json),
        required: ["query"]
      )
    end

    def call(arguments : Hash(String, JSON::Any)) : AmberCLI::MCP::ToolOutcome
      query = string_argument(arguments, "query")
      return AmberCLI::MCP::ToolOutcome.failure("`query` is required and must be a string.") unless query
      return AmberCLI::MCP::ToolOutcome.failure("`query` must not be blank.") if query.blank?

      limit = arguments["limit"]?.try(&.as_i?) || AmberCLI::MCP::DocumentIndex::DEFAULT_MATCH_LIMIT
      limit = limit.clamp(1, AmberCLI::MCP::DocumentIndex::DEFAULT_MATCH_LIMIT)

      matches = AmberCLI::MCP::DocumentIndex.search(query, limit)
      if matches.empty?
        return AmberCLI::MCP::ToolOutcome.data(
          "No matches for #{query.inspect}.",
          {"query" => query, "matches" => [] of String, "documents" => AmberCLI::MCP::DocumentIndex.ids}
        )
      end

      payload = {
        "query"   => query,
        "matches" => matches.map do |match|
          {
            "document"   => match.document,
            "lineNumber" => match.line_number,
            "line"       => match.line,
            "context"    => match.context,
          }
        end,
      }

      AmberCLI::MCP::ToolOutcome.data("#{matches.size} match(es) for #{query.inspect}", payload)
    end
  end
end
