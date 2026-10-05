require "../core/base_command"
require "../mcp/server"

# The `mcp` command runs an MCP (Model Context Protocol) server so agents can
# introspect and scaffold Amber applications.
#
# ## Usage
# ```
# amber mcp serve [options]
# ```
#
# ## Options
# - `--host HOST` - Address to bind (default: 127.0.0.1)
# - `--port PORT` - Port to bind (default: 5757)
# - `--allow-remote` - Permit binding to a non-loopback address
#
# ## Examples
# ```
# # Serve on the default loopback endpoint
# amber mcp serve
#
# # Serve on a different port
# amber mcp serve --port 8080
# ```
#
# ## Security
# The server has no authentication. It binds to loopback only, and refuses a
# non-loopback bind unless `--allow-remote` is given explicitly.
module AmberCLI::Commands
  class McpCommand < AmberCLI::Core::BaseCommand
    # Raised when the requested bind would expose the server beyond this machine
    # without the operator having asked for it.
    #
    # The refusal raises rather than exiting inline so that it is a behavior
    # something can assert against; a guard whose only expression is `exit` can
    # only be tested by launching a process.
    class RemoteBindRefusedError < Exception
    end

    SUBCOMMANDS = ["serve"]

    # Addresses that expose the server beyond this machine.
    NON_LOOPBACK_HOSTS = ["0.0.0.0", "::", "*"]

    getter host : String = AmberCLI::MCP::Server::DEFAULT_HOST
    getter port : Int32 = AmberCLI::MCP::Server::DEFAULT_PORT
    getter? allow_remote : Bool = false

    def help_description : String
      <<-HELP
        Run an MCP server exposing Amber CLI tools to agents

        Usage: amber mcp serve [options]

        Serves the Model Context Protocol over Streamable HTTP on a single
        endpoint, POST /mcp. Both the stateless 2026-07-28 revision and the
        initialize-handshake revisions (2025-11-25, 2025-06-18) are answered on
        that endpoint; no session state is kept in either case.

        Tools:
          amber_version       Report CLI, Crystal and protocol versions
          project_info        Inspect a directory for an Amber application
          list_routes         List routes declared in config/routes.cr
          list_generators     List available generators and their arguments
          search_docs         Search the bundled documentation
          read_doc            Read one bundled documentation file
          create_new_app      Scaffold a new application (writes to disk)
          generate_component  Run a generator in an application (writes to disk)

        Security: there is no authentication. The server binds to 127.0.0.1 and
        refuses a non-loopback bind unless --allow-remote is passed.

        Examples:
          amber mcp serve
          amber mcp serve --port 8080
        HELP
    end

    def setup_command_options
      option_parser.on("--host=HOST", "Address to bind (default: #{AmberCLI::MCP::Server::DEFAULT_HOST})") do |value|
        @parsed_options["host"] = value
        @host = value
      end

      option_parser.on("--port=PORT", "Port to bind (default: #{AmberCLI::MCP::Server::DEFAULT_PORT})") do |value|
        parsed = value.to_i?
        unless parsed && (1..65_535).includes?(parsed)
          error "Invalid port '#{value}'. Expected an integer between 1 and 65535."
          exit(1)
        end
        @parsed_options["port"] = value
        @port = parsed
      end

      option_parser.on("--allow-remote", "Permit binding to a non-loopback address (no authentication is performed)") do
        @parsed_options["allow_remote"] = true
        @allow_remote = true
      end

      option_parser.separator ""
      option_parser.separator "Usage: amber mcp serve [options]"
    end

    def execute
      subcommand = remaining_arguments.first? || "serve"

      unless SUBCOMMANDS.includes?(subcommand)
        error "Unknown mcp subcommand '#{subcommand}'. Available: #{SUBCOMMANDS.join(", ")}"
        puts option_parser
        exit!(error: true)
      end

      serve
    end

    # Refuses a remote bind that was not asked for.
    #
    # v1 has no authentication, so a non-loopback bind publishes filesystem-writing
    # tools to every host that can reach the port. The refusal is the security
    # model, not a warning.
    def validate_bind!
      return unless NON_LOOPBACK_HOSTS.includes?(@host)
      return if @allow_remote

      raise RemoteBindRefusedError.new(
        "Refusing to bind #{@host}: `amber mcp serve` performs no authentication. " \
        "Binding a non-loopback address would expose create_new_app and generate_component, " \
        "which write to this machine's filesystem, to anyone who can reach this port. " \
        "Pass --allow-remote to override, and put an authenticating proxy in front of it."
      )
    end

    private def serve
      begin
        validate_bind!
      rescue ex : RemoteBindRefusedError
        error ex.message.to_s
        exit!(error: true)
      end

      server = AmberCLI::MCP::Server.new(host: @host, port: @port, allow_remote: @allow_remote)
      address = server.bind

      if @allow_remote && NON_LOOPBACK_HOSTS.includes?(@host)
        warning "Serving on #{address} with no authentication. Remote exposure is unsupported:"
        warning "there is no OAuth in this release, and every reachable client can write files."
      end

      info "Amber MCP server listening on #{server.endpoint_url}"
      info "Health check: http://#{@host}:#{server.port}#{AmberCLI::MCP::Server::HEALTH_PATH}"
      info "Protocol revisions: #{AmberCLI::MCP::Protocol::SUPPORTED_VERSIONS.join(", ")}"
      info "Press Ctrl-C to stop."

      Process.on_terminate do
        puts ""
        info "Shutting down."
        server.close
      end

      server.listen
    end
  end
end

# Register the command.
#
# The alias list is built rather than written as `[] of String`, which the parser
# reads as the start of a proc type once a second argument follows it.
AmberCLI::Core::CommandRegistry.register("mcp", Array(String).new, AmberCLI::Commands::McpCommand)
