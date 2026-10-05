# :nodoc:
require "json"
require "base64"
require "mcprotocol"

# Protocol-level constants shared by the MCP transport, dispatcher and tools.
#
# The `mcprotocol` shard supplies the message *schema*; this module supplies the
# Streamable HTTP *binding* details that the schema deliberately leaves out —
# header names, error codes and the `_meta` keys that carry per-request protocol
# state in the stateless 2026-07-28 revision.
module AmberCLI::MCP::Protocol
  # The server identity reported in `InitializeResult`, `DiscoverResult` and the
  # `io.modelcontextprotocol/serverInfo` result metadata.
  SERVER_NAME = "amber-cli"

  # Revisions this server speaks, newest first. Mirrors the shard so the two can
  # never drift apart silently.
  SUPPORTED_VERSIONS = ::MCProtocol::SUPPORTED_PROTOCOL_VERSIONS

  # The stateless revision: no `initialize` handshake, per-request `_meta`,
  # mirrored HTTP headers and `server/discover`.
  MODERN_VERSION = ::MCProtocol::PROTOCOL_VERSION_2026_07_28

  # The newest revision that still uses the `initialize` handshake. This is the
  # revision Claude Desktop negotiates today, so it is what we answer an
  # `initialize` request with when the client asks for something newer.
  LATEST_LEGACY_VERSION = ::MCProtocol::PROTOCOL_VERSION_2025_11_25

  # Revisions reachable through the `initialize` handshake.
  LEGACY_VERSIONS = [
    ::MCProtocol::PROTOCOL_VERSION_2025_11_25,
    ::MCProtocol::PROTOCOL_VERSION_2025_06_18,
  ]

  # HTTP headers the Streamable HTTP binding mirrors from the request body.
  # Compared case-insensitively per RFC 9110; values are case-sensitive.
  PROTOCOL_VERSION_HEADER = "MCP-Protocol-Version"
  METHOD_HEADER           = "Mcp-Method"
  NAME_HEADER             = "Mcp-Name"

  # `_meta` keys reserved by the specification for per-request protocol state.
  META_PROTOCOL_VERSION    = "io.modelcontextprotocol/protocolVersion"
  META_CLIENT_INFO         = "io.modelcontextprotocol/clientInfo"
  META_CLIENT_CAPABILITIES = "io.modelcontextprotocol/clientCapabilities"
  META_SERVER_INFO         = "io.modelcontextprotocol/serverInfo"

  # JSON-RPC error codes. `-32020`..`-32099` is the range the MCP specification
  # reserves for itself; we emit only codes it defines.
  PARSE_ERROR      = -32700
  INVALID_REQUEST  = -32600
  METHOD_NOT_FOUND = -32601
  INVALID_PARAMS   = -32602
  INTERNAL_ERROR   = -32603

  # The HTTP headers do not match the corresponding request body values, or a
  # required header is missing or malformed.
  HEADER_MISMATCH = -32020
  # A capability the request needs was absent from `clientCapabilities`.
  MISSING_REQUIRED_CLIENT_CAPABILITY = -32021
  # The requested protocol version is one this server does not implement.
  UNSUPPORTED_PROTOCOL_VERSION = -32022

  # Methods whose `Mcp-Name` header mirrors `params.name`.
  NAMED_BY_PARAMS_NAME = ["tools/call", "prompts/get"]
  # Methods whose `Mcp-Name` header mirrors `params.uri`.
  NAMED_BY_PARAMS_URI = ["resources/read"]

  # How long a client may cache a list result, in milliseconds. Tool definitions
  # are compiled into the binary, so they cannot change while the process lives;
  # an hour is conservative rather than meaningful.
  LIST_RESULT_TTL_MS = 3_600_000_i64

  # Tool definitions carry no per-user data, so intermediaries may share them.
  LIST_RESULT_CACHE_SCOPE = "public"

  # Sentinel wrapper for header values that cannot be represented as plain ASCII.
  BASE64_SENTINEL_PREFIX = "=?base64?"
  BASE64_SENTINEL_SUFFIX = "?="

  # Decodes a header value that may use the Base64 sentinel format.
  #
  # Servers MUST decode `Mcp-Name` and `Mcp-Param-*` values before comparing them
  # to the request body, otherwise any non-ASCII tool name fails validation.
  # Returns the value unchanged when it is not sentinel-wrapped, and `nil` when
  # it is wrapped but the payload is not valid Base64.
  def self.decode_header_value(value : String) : String?
    return value unless value.starts_with?(BASE64_SENTINEL_PREFIX) && value.ends_with?(BASE64_SENTINEL_SUFFIX)

    encoded = value[BASE64_SENTINEL_PREFIX.size...(value.size - BASE64_SENTINEL_SUFFIX.size)]
    String.new(Base64.decode(encoded))
  rescue Base64::Error
    nil
  end

  # Whether *version* uses per-request metadata rather than an `initialize`
  # handshake.
  def self.modern?(version : String) : Bool
    version == MODERN_VERSION
  end

  # Whether this server implements *version*.
  def self.supported?(version : String) : Bool
    SUPPORTED_VERSIONS.includes?(version)
  end
end
