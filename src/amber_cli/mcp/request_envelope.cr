# :nodoc:
require "json"
require "http/headers"
require "./protocol"
require "./json_rpc_error"

module AmberCLI::MCP
  # One parsed, validated JSON-RPC message together with the transport metadata
  # that governs how it must be answered.
  #
  # Parsing dispatches on the `method` string and never decodes the body into a
  # broad union type. Crystal's JSON union deserialization picks the first member
  # that parses, and MCP request types are largely all-optional objects with the
  # same shape, so a union decode silently yields the wrong request class.
  class RequestEnvelope
    # The raw JSON-RPC `id`. `nil` for notifications.
    getter id : JSON::Any?

    # The JSON-RPC method string. Dispatch happens on this, before any params are
    # decoded into a concrete type.
    getter method : String

    getter params : JSON::Any?

    # The `_meta` object from `params`, if any.
    getter meta : JSON::Any?

    # The protocol version the client actually stated, or `nil` if it said
    # nothing. Distinct from `protocol_version`, which fills in a default.
    getter declared_version : String?

    # The revision governing this request. Determines the era: modern requests
    # carry mirrored headers and per-request `_meta`, legacy ones do not.
    getter protocol_version : String

    def initialize(
      @method : String,
      @protocol_version : String,
      @id : JSON::Any? = nil,
      @params : JSON::Any? = nil,
      @meta : JSON::Any? = nil,
      @declared_version : String? = nil,
    )
    end

    # A message with no `id` expects no response, only a transport acknowledgement.
    def notification? : Bool
      @id.nil?
    end

    # Whether this request uses the stateless per-request-metadata era.
    def modern? : Bool
      Protocol.modern?(@protocol_version)
    end

    # The client's self-reported identity, for logging only. The specification is
    # explicit that this is unverified and must not drive behavior.
    def client_info : JSON::Any?
      @meta.try(&.as_h?).try(&.[Protocol::META_CLIENT_INFO]?)
    end

    # Parses *body* and validates it against *headers*.
    #
    # Raises `JsonRpcError` for anything malformed; the transport turns that into
    # the paired HTTP status and JSON-RPC error body.
    def self.parse(body : String, headers : HTTP::Headers) : RequestEnvelope
      json = begin
        JSON.parse(body)
      rescue ex : JSON::ParseException
        raise JsonRpcError.parse_error(ex.message.to_s)
      end

      object = json.as_h?
      raise JsonRpcError.invalid_request("body must be a JSON object") unless object

      method = object["method"]?.try(&.as_s?)
      raise JsonRpcError.invalid_request("missing or non-string \"method\"") unless method

      # An absent id means notification; an explicitly null id is malformed, and
      # the two are only distinguishable through the key itself.
      id = nil.as(JSON::Any?)
      if object.has_key?("id")
        candidate = object["id"]
        raise JsonRpcError.invalid_request("\"id\" must not be null") if candidate.raw.nil?
        id = candidate
      end

      params = object["params"]?
      meta = params.try(&.as_h?).try(&.["_meta"]?)

      declared_version = resolve_declared_version(method, params, meta, headers)
      protocol_version = resolve_protocol_version(method, declared_version)

      envelope = new(
        method: method,
        protocol_version: protocol_version,
        id: id,
        params: params,
        meta: meta,
        declared_version: declared_version,
      )

      envelope.validate_modern_request!(headers) if envelope.modern?
      envelope
    end

    # Reads the version the client stated, preferring the body over the header.
    #
    # The body is the source of truth; a header that disagrees with it is a
    # validation failure rather than an alternative reading, because an
    # intermediary routing on the header and a server executing on the body would
    # otherwise act on different requests.
    private def self.resolve_declared_version(method : String, params : JSON::Any?, meta : JSON::Any?, headers : HTTP::Headers) : String?
      body_version = meta.try(&.as_h?).try(&.[Protocol::META_PROTOCOL_VERSION]?).try(&.as_s?)
      header_version = headers[Protocol::PROTOCOL_VERSION_HEADER]?

      if body_version && header_version && body_version != header_version
        raise JsonRpcError.header_mismatch(
          "#{Protocol::PROTOCOL_VERSION_HEADER} header value #{header_version.inspect} " \
          "does not match body value #{body_version.inspect}"
        )
      end

      return body_version if body_version
      return header_version if header_version

      # The legacy handshake carries the version in the params, not in `_meta`.
      return params.try(&.as_h?).try(&.["protocolVersion"]?).try(&.as_s?) if method == "initialize"

      nil
    end

    # Resolves the revision that governs this request.
    #
    # A client that states nothing is treated as legacy rather than rejected: the
    # mirrored-header rules only exist from 2026-07-28, so assuming the modern era
    # for a silent client would fail it with a header error it cannot act on.
    private def self.resolve_protocol_version(method : String, declared_version : String?) : String
      return Protocol::LATEST_LEGACY_VERSION if declared_version.nil?
      raise JsonRpcError.unsupported_protocol_version(declared_version) unless Protocol.supported?(declared_version)

      # `initialize` does not exist in the modern era. A client that sends the
      # handshake while claiming 2026-07-28 is contradicting itself, so we answer
      # on the newest revision that actually has a handshake.
      return Protocol::LATEST_LEGACY_VERSION if method == "initialize" && Protocol.modern?(declared_version)

      declared_version
    end

    # Enforces the header mirroring the 2026-07-28 Streamable HTTP binding requires.
    protected def validate_modern_request!(headers : HTTP::Headers)
      unless headers[Protocol::PROTOCOL_VERSION_HEADER]?
        raise JsonRpcError.header_mismatch("missing required #{Protocol::PROTOCOL_VERSION_HEADER} header")
      end

      header_method = headers[Protocol::METHOD_HEADER]?
      raise JsonRpcError.header_mismatch("missing required #{Protocol::METHOD_HEADER} header") unless header_method

      unless header_method == @method
        raise JsonRpcError.header_mismatch(
          "#{Protocol::METHOD_HEADER} header value #{header_method.inspect} does not match body value #{@method.inspect}"
        )
      end

      validate_name_header!(headers)
      validate_required_meta!
    end

    private def validate_name_header!(headers : HTTP::Headers)
      body_name =
        if Protocol::NAMED_BY_PARAMS_NAME.includes?(@method)
          @params.try(&.as_h?).try(&.["name"]?).try(&.as_s?)
        elsif Protocol::NAMED_BY_PARAMS_URI.includes?(@method)
          @params.try(&.as_h?).try(&.["uri"]?).try(&.as_s?)
        end

      return unless body_name

      raw_header = headers[Protocol::NAME_HEADER]?
      raise JsonRpcError.header_mismatch("missing required #{Protocol::NAME_HEADER} header") unless raw_header

      decoded = Protocol.decode_header_value(raw_header)
      unless decoded
        raise JsonRpcError.header_mismatch("#{Protocol::NAME_HEADER} header value is not valid Base64")
      end

      unless decoded == body_name
        raise JsonRpcError.header_mismatch(
          "#{Protocol::NAME_HEADER} header value #{decoded.inspect} does not match body value #{body_name.inspect}"
        )
      end
    end

    # `protocolVersion` and `clientCapabilities` are REQUIRED on every modern
    # request; a request missing either is malformed params, not a header problem.
    private def validate_required_meta!
      fields = @meta.try(&.as_h?)
      unless fields
        raise JsonRpcError.invalid_params("modern requests require a params._meta object")
      end

      unless fields[Protocol::META_PROTOCOL_VERSION]?.try(&.as_s?)
        raise JsonRpcError.invalid_params("params._meta.#{Protocol::META_PROTOCOL_VERSION} is required")
      end

      unless fields[Protocol::META_CLIENT_CAPABILITIES]?.try(&.as_h?)
        raise JsonRpcError.invalid_params("params._meta.#{Protocol::META_CLIENT_CAPABILITIES} is required")
      end
    end
  end
end
