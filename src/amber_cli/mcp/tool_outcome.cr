# :nodoc:
require "json"

module AmberCLI::MCP
  # What a tool returns: human-readable text, optional machine-readable data, and
  # whether the call failed.
  #
  # Tool failures travel in the result rather than as JSON-RPC errors so that the
  # model can see what went wrong and correct itself; a protocol error is invisible
  # to it.
  struct ToolOutcome
    getter text : String
    getter structured : JSON::Any?
    getter? error : Bool

    def initialize(@text : String, @structured : JSON::Any? = nil, @error : Bool = false)
    end

    # A successful text-only result.
    def self.ok(text : String) : ToolOutcome
      new(text)
    end

    # A successful result carrying structured data.
    #
    # The payload is emitted twice on purpose: fenced in the text block for models
    # reading the transcript, and in `structuredContent` for callers that parse.
    def self.data(summary : String, payload : JSON::Any) : ToolOutcome
      pretty = payload.to_pretty_json
      new("#{summary}\n\n```json\n#{pretty}\n```", payload)
    end

    # :ditto:
    def self.data(summary : String, payload) : ToolOutcome
      data(summary, JSON.parse(payload.to_json))
    end

    # A failed tool call.
    def self.failure(text : String) : ToolOutcome
      new(text, nil, true)
    end
  end
end
