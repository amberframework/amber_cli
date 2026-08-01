require "spec"
require "file_utils"
require "http/client"
require "json"
require "../../src/amber_cli"

# A directory that exists only for the duration of the block.
def with_mcp_tempdir(&)
  dir = File.join(Dir.tempdir, "amber_mcp_spec_#{Random::Secure.hex(8)}")
  Dir.mkdir_p(dir)
  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end

# Writes a minimal Amber application into *dir* and yields its path.
#
# The fixture is written directly rather than produced by `amber new`: running
# the real generator would need a compiled binary and a `shards install`, which
# would make every tool spec depend on the network.
def with_fixture_app(name : String = "fixture_app", &)
  with_mcp_tempdir do |dir|
    app = File.join(dir, name)
    Dir.mkdir_p(File.join(app, "config"))
    Dir.mkdir_p(File.join(app, "src"))
    Dir.mkdir_p(File.join(app, "spec"))

    File.write(File.join(app, "shard.yml"), <<-YAML)
      name: #{name}
      version: 0.1.0

      dependencies:
        amber:
          github: amberframework/amber
          version: 2.0.0-beta.2
      YAML

    File.write(File.join(app, ".amber.yml"), <<-YAML)
      database: sqlite
      language: ecr
      model: none
      YAML

    File.write(File.join(app, "config", "routes.cr"), <<-CRYSTAL)
      Amber::Server.configure do |app|
        pipeline :web do
          plug Amber::Pipe::Logger.new
        end

        routes :web do
          get "/", HomeController, :index
          post "/sessions", SessionsController, :create
          resources "/posts", PostsController
        end
      end
      CRYSTAL

    yield app
  end
end

# Boots the MCP server on an ephemeral port, yields a client bound to it, and
# shuts it down afterwards.
def with_mcp_server(allow_remote : Bool = false, &)
  server = AmberCLI::MCP::Server.new(host: "127.0.0.1", port: 0, allow_remote: allow_remote)
  address = server.bind
  spawn { server.listen }
  # Yield to the scheduler so the accept loop is running before the first request.
  Fiber.yield

  client = HTTP::Client.new("127.0.0.1", address.port)
  begin
    yield client, address.port
  ensure
    client.close
    server.close
  end
end

# Headers a conforming 2026-07-28 client sends.
def modern_headers(method : String, name : String? = nil) : HTTP::Headers
  headers = HTTP::Headers{
    "Content-Type"         => "application/json",
    "Accept"               => "application/json, text/event-stream",
    "MCP-Protocol-Version" => "2026-07-28",
    "Mcp-Method"           => method,
  }
  headers["Mcp-Name"] = name if name
  headers
end

# The `_meta` block every modern request must carry.
def modern_meta(version : String = "2026-07-28") : Hash(String, JSON::Any)
  {
    "io.modelcontextprotocol/protocolVersion"    => JSON::Any.new(version),
    "io.modelcontextprotocol/clientInfo"         => JSON.parse({"name" => "amber-spec", "version" => "1.0.0"}.to_json),
    "io.modelcontextprotocol/clientCapabilities" => JSON.parse("{}"),
  }
end

# Headers a 2025-11-25 (Claude Desktop era) client sends after the handshake.
def legacy_headers : HTTP::Headers
  HTTP::Headers{
    "Content-Type" => "application/json",
    "Accept"       => "application/json, text/event-stream",
  }
end

def parse_body(response : HTTP::Client::Response) : JSON::Any
  JSON.parse(response.body)
end
