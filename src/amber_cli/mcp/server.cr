# :nodoc:
require "http/server"
require "json"
require "uri"
require "./protocol"
require "./json_rpc_error"
require "./request_envelope"
require "./dispatcher"

module AmberCLI::MCP
  # Streamable HTTP transport for the Amber MCP server.
  #
  # One endpoint, `POST /mcp`, answering each request independently. No session is
  # ever created: no `Mcp-Session-Id` is minted or echoed, `Last-Event-ID` is
  # ignored, and `GET`/`DELETE` on the endpoint are refused. Both eras are served
  # on the same endpoint — a client that opens with `initialize` gets the classic
  # lifecycle, one that sends header-versioned 2026-07-28 requests is served
  # statelessly — and neither path retains anything between requests.
  class Server
    DEFAULT_HOST = "127.0.0.1"
    DEFAULT_PORT = 5757

    ENDPOINT_PATH = "/mcp"
    HEALTH_PATH   = "/healthz"

    # Ceiling on a request body. A tool call is a small JSON object; anything
    # larger is a mistake or an attempt to exhaust memory.
    MAX_BODY_BYTES = 4 * 1024 * 1024

    # Hosts whose `Origin` is accepted when bound to loopback. Anything else is a
    # cross-origin browser request, which is the DNS-rebinding path the
    # specification requires servers to close.
    LOCAL_ORIGIN_HOSTS = ["localhost", "127.0.0.1", "::1", "[::1]"]

    getter host : String
    getter port : Int32
    getter dispatcher : Dispatcher

    def initialize(
      @host : String = DEFAULT_HOST,
      @port : Int32 = DEFAULT_PORT,
      @allow_remote : Bool = false,
      @dispatcher : Dispatcher = Dispatcher.new,
    )
      @server = HTTP::Server.new { |context| handle(context) }
    end

    # Binds the listening socket and returns the address actually assigned.
    #
    # Binding is separate from listening so a caller — a spec, in practice — can
    # ask for port 0, learn the ephemeral port the kernel chose, and only then
    # start serving.
    def bind : Socket::IPAddress
      address = @server.bind_tcp(@host, @port)
      @port = address.port
      address
    end

    # Serves until `close`. Blocks the calling fiber.
    def listen
      @server.listen
    end

    def close
      @server.close
    end

    def closed? : Bool
      @server.closed?
    end

    # The URL the endpoint is reachable at, for printing at startup.
    def endpoint_url : String
      displayed_host = @host.includes?(':') ? "[#{@host}]" : @host
      "http://#{displayed_host}:#{@port}#{ENDPOINT_PATH}"
    end

    private def handle(context : HTTP::Server::Context)
      case {context.request.method, context.request.path}
      when {"GET", HEALTH_PATH}
        respond_health(context)
      when {"POST", ENDPOINT_PATH}
        handle_endpoint(context)
      when {"GET", ENDPOINT_PATH}, {"DELETE", ENDPOINT_PATH}
        # 2025-03-26..2025-11-25 used GET for a standalone SSE stream and DELETE
        # to end a session. Neither mechanism exists in this revision.
        respond_method_not_allowed(context)
      else
        respond_not_found(context)
      end
    rescue ex : Exception
      respond_error(context, JsonRpcError.internal_error(ex.message.to_s), nil)
    end

    private def respond_health(context : HTTP::Server::Context)
      context.response.status = HTTP::Status::OK
      context.response.content_type = "text/plain"
      context.response.print "ok"
    end

    private def respond_method_not_allowed(context : HTTP::Server::Context)
      context.response.status = HTTP::Status::METHOD_NOT_ALLOWED
      context.response.headers["Allow"] = "POST"
      context.response.content_type = "text/plain"
      context.response.print "Only POST is supported on #{ENDPOINT_PATH}."
    end

    private def respond_not_found(context : HTTP::Server::Context)
      context.response.status = HTTP::Status::NOT_FOUND
      context.response.content_type = "text/plain"
      context.response.print "Not found. The MCP endpoint is POST #{ENDPOINT_PATH}."
    end

    private def handle_endpoint(context : HTTP::Server::Context)
      unless origin_allowed?(context.request.headers["Origin"]?)
        return respond_forbidden(context)
      end

      body = read_body(context.request)
      # The id is recovered before validation so that an error response can still
      # be correlated with the request that caused it. A client whose request was
      # rejected for a bad header cannot match a null-id error to anything.
      id = peek_id(body)

      begin
        envelope = RequestEnvelope.parse(body, context.request.headers)
        outcome = @dispatcher.dispatch(envelope)

        context.response.status = outcome.status
        if payload = outcome.body
          write_payload(context, payload)
        end
      rescue error : JsonRpcError
        respond_error(context, error, id)
      end
    rescue error : JsonRpcError
      respond_error(context, error, nil)
    end

    # Best-effort read of the JSON-RPC id. A body too malformed to yield one gets
    # a null id, which JSON-RPC allows for exactly this case.
    private def peek_id(body : String) : JSON::Any?
      json = JSON.parse(body)
      candidate = json.as_h?.try(&.["id"]?)
      candidate.try { |value| value.raw.nil? ? nil : value }
    rescue JSON::ParseException
      nil
    end

    private def respond_forbidden(context : HTTP::Server::Context)
      context.response.status = HTTP::Status::FORBIDDEN
      context.response.content_type = "application/json"
      context.response.print JsonRpcError.new(
        Protocol::INVALID_REQUEST,
        "Origin not allowed",
        HTTP::Status::FORBIDDEN
      ).to_response(nil)
    end

    private def respond_error(context : HTTP::Server::Context, error : JsonRpcError, id : JSON::Any?)
      context.response.status = error.http_status
      context.response.content_type = "application/json"
      context.response.print error.to_response(id)
    end

    # Chooses the response framing.
    #
    # A conforming 2026-07-28 client sends `Accept: application/json,
    # text/event-stream` on every request, so "mentions text/event-stream" cannot
    # be the trigger — that would force SSE always. SSE is used only when the
    # client accepts the event stream *and not* JSON, i.e. when it asked for a
    # stream specifically.
    private def write_payload(context : HTTP::Server::Context, payload : String)
      if sse_preferred?(context.request.headers["Accept"]?)
        context.response.content_type = "text/event-stream"
        context.response.headers["Cache-Control"] = "no-cache"
        # Tells reverse proxies not to buffer, which would otherwise hold the
        # event until the connection closed.
        context.response.headers["X-Accel-Buffering"] = "no"
        context.response.print "event: message\ndata: #{payload}\n\n"
      else
        context.response.content_type = "application/json"
        context.response.print payload
      end
    end

    private def sse_preferred?(accept : String?) : Bool
      return false unless accept

      normalized = accept.downcase
      return false unless normalized.includes?("text/event-stream")

      !normalized.includes?("application/json") && !normalized.includes?("*/*")
    end

    private def read_body(request : HTTP::Request) : String
      io = request.body
      raise JsonRpcError.invalid_request("empty request body") unless io

      if (length = request.content_length) && length > MAX_BODY_BYTES
        raise JsonRpcError.invalid_request("request body exceeds #{MAX_BODY_BYTES} bytes")
      end

      body = io.gets_to_end
      raise JsonRpcError.invalid_request("empty request body") if body.empty?
      raise JsonRpcError.invalid_request("request body exceeds #{MAX_BODY_BYTES} bytes") if body.bytesize > MAX_BODY_BYTES

      body
    end

    # Validates `Origin` to close the DNS-rebinding path: without this, any web
    # page the user visits could drive a localhost MCP server that has no auth.
    private def origin_allowed?(origin : String?) : Bool
      # Non-browser clients send no Origin at all; there is nothing to validate.
      return true unless origin
      # Once the operator has opted into remote exposure, origin filtering is not
      # the control that is protecting them.
      return true if @allow_remote

      uri = URI.parse(origin)
      host = uri.host
      return false unless host

      LOCAL_ORIGIN_HOSTS.includes?(host)
    rescue URI::Error
      false
    end
  end
end
