# :nodoc:
require "./base_tool"
require "./tools/amber_version_tool"
require "./tools/project_info_tool"
require "./tools/list_routes_tool"
require "./tools/list_generators_tool"
require "./tools/search_docs_tool"
require "./tools/read_doc_tool"
require "./tools/create_new_app_tool"
require "./tools/generate_component_tool"

module AmberCLI::MCP
  # The set of tools an MCP server exposes.
  #
  # Ordinary construction registers the v1 set; specs build empty registries and
  # register stubs so a tool spec never has to boot the whole server.
  class ToolRegistry
    getter tools : Hash(String, BaseTool)

    def initialize
      @tools = {} of String => BaseTool
    end

    # The v1 tool set: read-only introspection plus the two scaffolding tools.
    def self.default : ToolRegistry
      registry = new
      registry.register(Tools::AmberVersionTool.new)
      registry.register(Tools::ProjectInfoTool.new)
      registry.register(Tools::ListRoutesTool.new)
      registry.register(Tools::ListGeneratorsTool.new)
      registry.register(Tools::SearchDocsTool.new)
      registry.register(Tools::ReadDocTool.new)
      registry.register(Tools::CreateNewAppTool.new)
      registry.register(Tools::GenerateComponentTool.new)
      registry
    end

    def register(tool : BaseTool) : BaseTool
      @tools[tool.name] = tool
    end

    def []?(name : String) : BaseTool?
      @tools[name]?
    end

    def size : Int32
      @tools.size
    end

    def names : Array(String)
      @tools.keys.to_a
    end

    # Tool definitions in registration order, for `tools/list`.
    def definitions : Array(::MCProtocol::Tool)
      @tools.values.map(&.definition)
    end
  end
end
