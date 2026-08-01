# :nodoc:
require "json"
require "http/status"
require "./protocol"

module AmberCLI::MCP
  # A JSON-RPC error that the dispatcher raises and the transport renders.
  #
  # Carrying the HTTP status alongside the JSON-RPC code keeps the two in sync:
  # the specification pairs specific codes with specific statuses (a `-32601`
  # must be a `404`, a `-32022` must be a `400`), and splitting that pairing
  # across two layers is how they drift.
  class JsonRpcError < Exception
    getter code : Int32
    getter data : JSON::Any?
    getter http_status : HTTP::Status

    def initialize(@code : Int32, message : String, @http_status : HTTP::Status = HTTP::Status::BAD_REQUEST, @data : JSON::Any? = nil)
      super(message)
    end

    # Renders the JSON-RPC error response body.
    #
    # *id* is echoed from the request when it could be read; a request too
    # malformed to yield an id gets a null id, as JSON-RPC requires.
    def to_response(id : JSON::Any?) : String
      JSON.build do |json|
        json.object do
          json.field "jsonrpc", "2.0"
          json.field "id" { (id || JSON::Any.new(nil)).to_json(json) }
          json.field "error" do
            json.object do
              json.field "code", code
              json.field "message", message.to_s
              if payload = data
                json.field "data" { payload.to_json(json) }
              end
            end
          end
        end
      end
    end

    # The request body could not be parsed as JSON.
    def self.parse_error(detail : String) : JsonRpcError
      new(Protocol::PARSE_ERROR, "Parse error: #{detail}")
    end

    # The payload parsed but is not a well-formed JSON-RPC request.
    def self.invalid_request(detail : String) : JsonRpcError
      new(Protocol::INVALID_REQUEST, "Invalid Request: #{detail}")
    end

    # The method is well-formed but this server does not implement it.
    #
    # The specification requires `404 Not Found` here so that a client can tell a
    # modern server that lacks the method from a legacy server that does not host
    # the endpoint at all.
    def self.method_not_found(method : String) : JsonRpcError
      new(
        Protocol::METHOD_NOT_FOUND,
        "Method not found: #{method}",
        HTTP::Status::NOT_FOUND,
        JSON.parse({"method" => method}.to_json)
      )
    end

    # A required parameter is missing or has the wrong shape.
    def self.invalid_params(detail : String) : JsonRpcError
      new(Protocol::INVALID_PARAMS, "Invalid params: #{detail}")
    end

    # A mirrored HTTP header is missing, malformed, or disagrees with the body.
    def self.header_mismatch(detail : String) : JsonRpcError
      new(Protocol::HEADER_MISMATCH, "Header mismatch: #{detail}")
    end

    # The client asked for a protocol revision this server does not implement.
    #
    # `data.supported` is what lets the client retry rather than give up, so it is
    # not optional in practice.
    def self.unsupported_protocol_version(requested : String) : JsonRpcError
      new(
        Protocol::UNSUPPORTED_PROTOCOL_VERSION,
        "Unsupported protocol version",
        HTTP::Status::BAD_REQUEST,
        JSON.parse({
          "supported" => Protocol::SUPPORTED_VERSIONS,
          "requested" => requested,
        }.to_json)
      )
    end

    # An unexpected server-side failure. Tool failures do not come through here —
    # they are reported inside the tool result with `isError` so the model can see
    # them and self-correct.
    def self.internal_error(detail : String) : JsonRpcError
      new(Protocol::INTERNAL_ERROR, "Internal error: #{detail}", HTTP::Status::INTERNAL_SERVER_ERROR)
    end
  end
end
