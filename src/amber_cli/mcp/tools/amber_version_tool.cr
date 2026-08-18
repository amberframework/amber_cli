# :nodoc:
require "json"
require "../base_tool"
require "../protocol"

module AmberCLI::MCP::Tools
  # Reports the CLI build and the protocol revisions this server speaks.
  class AmberVersionTool < AmberCLI::MCP::BaseTool
    def name : String
      "amber_version"
    end

    def title : String?
      "Amber CLI version"
    end

    def description : String
      <<-TEXT
        Report the version of the Amber CLI serving this MCP endpoint, the Crystal
        compiler it was built with, and the MCP protocol revisions it supports.
        Read-only; takes no arguments. Call this first to confirm which CLI build an
        agent is talking to before relying on generator or scaffolding behavior.
        TEXT
    end

    def input_schema : ::MCProtocol::ToolInputSchema
      ::MCProtocol::ToolInputSchema.new(
        properties: JSON.parse("{}"),
        required: [] of String
      )
    end

    def call(arguments : Hash(String, JSON::Any)) : AmberCLI::MCP::ToolOutcome
      payload = {
        "cliVersion"                => AmberCLI::VERSION,
        "crystalVersion"            => Crystal::VERSION,
        "mcpServerName"             => AmberCLI::MCP::Protocol::SERVER_NAME,
        "supportedProtocolVersions" => AmberCLI::MCP::Protocol::SUPPORTED_VERSIONS,
      }

      AmberCLI::MCP::ToolOutcome.data("Amber CLI v#{AmberCLI::VERSION}", payload)
    end
  end
end
