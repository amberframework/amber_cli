# :nodoc:
require "json"
require "http/status"
require "mcprotocol"
require "./protocol"
require "./json_rpc_error"
require "./request_envelope"
require "./tool_registry"

module AmberCLI::MCP
  # Turns a validated `RequestEnvelope` into an HTTP status and response body.
  #
  # Dispatch is on the `method` string, and only then are params decoded into a
  # concrete type. Decoding into a union of MCP request types instead would pick
  # whichever member happens to parse first: the request classes are almost all
  # all-optional objects, so a `tools/list` payload decodes cleanly as several of
  # them and the wrong handler runs with no error anywhere.
  class Dispatcher
    # Guidance handed to clients in `initialize` and `server/discover`.
    INSTRUCTIONS = <<-TEXT
      Amber CLI tools for inspecting and scaffolding Amber V2 applications.

      Every application-scoped tool takes an explicit absolute `path`; this server
      never infers a project from its own working directory. Start with
      `project_info` to confirm a directory is an Amber application, `list_routes`
      and `list_generators` to introspect it, and `search_docs` / `read_doc` for
      reference material.

      `create_new_app` and `generate_component` write to the filesystem. They are
      marked with a destructive hint and should be confirmed with the user before
      being called.
      TEXT

    # What a dispatched request becomes on the wire. A `nil` body means the status
    # carries the whole answer, as with the `202 Accepted` a notification gets.
    struct Outcome
      getter status : HTTP::Status
      getter body : String?

      def initialize(@status : HTTP::Status, @body : String? = nil)
      end
    end

    getter registry : ToolRegistry

    def initialize(@registry : ToolRegistry = ToolRegistry.default)
    end

    def dispatch(envelope : RequestEnvelope) : Outcome
      # A notification expects no response body, only an acknowledgement.
      return Outcome.new(HTTP::Status::ACCEPTED) if envelope.notification?

      case envelope.method
      when "initialize"
        handle_initialize(envelope)
      when "server/discover"
        handle_discover(envelope)
      when "ping"
        respond(envelope, JSON.parse("{}"))
      when "tools/list"
        handle_tools_list(envelope)
      when "tools/call"
        handle_tools_call(envelope)
      else
        raise JsonRpcError.method_not_found(envelope.method)
      end
    end

    # The legacy handshake. Answering it selects legacy semantics for this client,
    # but changes nothing on the server: no session is created and no state is
    # retained, so a client may interleave modern and legacy requests freely.
    private def handle_initialize(envelope : RequestEnvelope) : Outcome
      negotiated = envelope.protocol_version

      result = ::MCProtocol::InitializeResult.new(
        capabilities: server_capabilities,
        protocolVersion: negotiated,
        serverInfo: server_info,
        instructions: INSTRUCTIONS
      )

      respond(envelope, JSON.parse(result.to_json))
    end

    # The stateless replacement for the handshake: advertise every revision we
    # speak and let the client pick.
    private def handle_discover(envelope : RequestEnvelope) : Outcome
      result = ::MCProtocol::DiscoverResult.new(
        supportedVersions: Protocol::SUPPORTED_VERSIONS,
        capabilities: server_capabilities,
        instructions: INSTRUCTIONS,
        ttlMs: Protocol::LIST_RESULT_TTL_MS,
        cacheScope: Protocol::LIST_RESULT_CACHE_SCOPE
      )

      respond(envelope, JSON.parse(result.to_json))
    end

    private def handle_tools_list(envelope : RequestEnvelope) : Outcome
      result = ::MCProtocol::ListToolsResult.new(tools: @registry.definitions)

      # Cache hints are REQUIRED on list results from 2026-07-28 and meaningless
      # to earlier peers, which ignore unknown fields.
      if envelope.modern?
        result.ttlMs = Protocol::LIST_RESULT_TTL_MS
        result.cacheScope = Protocol::LIST_RESULT_CACHE_SCOPE
      end

      respond(envelope, JSON.parse(result.to_json))
    end

    private def handle_tools_call(envelope : RequestEnvelope) : Outcome
      params = envelope.params.try(&.as_h?)
      raise JsonRpcError.invalid_params("tools/call requires a params object") unless params

      tool_name = params["name"]?.try(&.as_s?)
      raise JsonRpcError.invalid_params("tools/call requires params.name") unless tool_name

      tool = @registry[tool_name]?
      # An unknown tool is a failure to *find* the tool, which the specification
      # puts at the protocol level rather than inside the result.
      raise JsonRpcError.method_not_found("tools/call: #{tool_name}") unless tool

      arguments = params["arguments"]?.try(&.as_h?) || {} of String => JSON::Any

      outcome =
        begin
          tool.call(arguments)
        rescue ex : Exception
          # A tool that raises is reported as a failed result, not a protocol
          # error: the model can only correct what it can see.
          ToolOutcome.failure("#{tool_name} raised #{ex.class}: #{ex.message}")
        end

      content = [] of ::MCProtocol::ContentBlock
      content << ::MCProtocol::TextContent.new(outcome.text)

      result = ::MCProtocol::CallToolResult.new(
        content: content,
        isError: outcome.error? || nil,
        structuredContent: outcome.structured
      )

      respond(envelope, JSON.parse(result.to_json))
    end

    private def server_capabilities : ::MCProtocol::ServerCapabilities
      ::MCProtocol::ServerCapabilities.new(
        tools: ::MCProtocol::ServerCapabilitiesTools.new(listChanged: false)
      )
    end

    private def server_info : ::MCProtocol::Implementation
      ::MCProtocol::Implementation.new(
        name: Protocol::SERVER_NAME,
        version: AmberCLI::VERSION,
        title: "Amber CLI"
      )
    end

    # Wraps *result* in a JSON-RPC response, adding the fields the negotiated
    # revision requires.
    private def respond(envelope : RequestEnvelope, result : JSON::Any) : Outcome
      fields = result.as_h.dup

      # REQUIRED on every result from 2026-07-28; absent means "complete" to
      # earlier clients, so emitting it unconditionally would still be safe — but
      # we keep pre-2026 responses byte-identical to what those clients expect.
      fields["resultType"] = JSON::Any.new(::MCProtocol::ResultType::COMPLETE) if envelope.modern?

      fields["_meta"] = merged_meta(fields["_meta"]?)

      body = JSON.build do |json|
        json.object do
          json.field "jsonrpc", "2.0"
          json.field "id" { (envelope.id || JSON::Any.new(nil)).to_json(json) }
          json.field "result" { JSON::Any.new(fields).to_json(json) }
        end
      end

      Outcome.new(HTTP::Status::OK, body)
    end

    # Servers SHOULD identify themselves in every result's `_meta` so a stateless
    # client knows who answered without any prior handshake.
    private def merged_meta(existing : JSON::Any?) : JSON::Any
      meta = existing.try(&.as_h?).try(&.dup) || {} of String => JSON::Any
      meta[Protocol::META_SERVER_INFO] = JSON.parse({
        "name"    => Protocol::SERVER_NAME,
        "version" => AmberCLI::VERSION,
      }.to_json)
      JSON::Any.new(meta)
    end
  end
end
