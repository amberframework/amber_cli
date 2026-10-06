require "json"

require "./api_cards"

module AmberLSP::Lookup
  struct LSPPosition
    include JSON::Serializable

    getter line : Int32
    getter character : Int32

    def initialize(@line : Int32 = 0, @character : Int32 = 0)
    end
  end

  struct LSPRange
    include JSON::Serializable

    getter start : LSPPosition
    getter end : LSPPosition

    def initialize(@start : LSPPosition, @end : LSPPosition)
    end
  end

  struct LSPLocation
    include JSON::Serializable

    getter uri : String
    getter range : LSPRange

    def initialize(@uri : String, @range : LSPRange)
    end
  end

  struct LSPWorkspaceSymbolData
    include JSON::Serializable

    @[JSON::Field(key: "status")]
    getter lookup_status : String
    getter freshness : String
    getter source_layer : String
    @[JSON::Field(key: "notes")]
    getter list_of_api_card_notes : Array(APICardNote)

    def initialize(
      @lookup_status : String,
      @freshness : String,
      @source_layer : String,
      @list_of_api_card_notes : Array(APICardNote) = [] of APICardNote,
    )
    end
  end

  struct LSPWorkspaceSymbol
    include JSON::Serializable

    @[JSON::Field(key: "name")]
    getter symbol_name : String
    @[JSON::Field(key: "kind")]
    getter symbol_kind : Int32
    getter location : LSPLocation
    @[JSON::Field(key: "containerName", emit_null: true)]
    getter container_name : String?
    @[JSON::Field(key: "data")]
    getter lookup_data : LSPWorkspaceSymbolData

    def initialize(
      @symbol_name : String,
      @symbol_kind : Int32,
      @location : LSPLocation,
      @container_name : String?,
      @lookup_data : LSPWorkspaceSymbolData,
    )
    end
  end

  struct LSPWorkspaceSymbolResponse
    include JSON::Serializable

    getter jsonrpc : String = "2.0"
    @[JSON::Field(emit_null: true)]
    getter id : Int64 | String | Nil
    @[JSON::Field(key: "result")]
    getter list_of_workspace_symbols : Array(LSPWorkspaceSymbol)

    def initialize(@id : Int64 | String | Nil, @list_of_workspace_symbols : Array(LSPWorkspaceSymbol))
    end
  end

  struct LSPMarkupContent
    include JSON::Serializable

    @[JSON::Field(key: "kind")]
    getter markup_kind : String = "markdown"
    @[JSON::Field(key: "value")]
    getter markdown_value : String

    def initialize(@markdown_value : String)
    end
  end

  struct DescribeAPIForHover
    include JSON::Serializable

    getter contents : LSPMarkupContent

    def initialize(@contents : LSPMarkupContent)
    end
  end

  struct LSPHoverResponse
    include JSON::Serializable

    getter jsonrpc : String = "2.0"
    @[JSON::Field(emit_null: true)]
    getter id : Int64 | String | Nil
    @[JSON::Field(emit_null: true)]
    getter result : DescribeAPIForHover?

    def initialize(@id : Int64 | String | Nil, @result : DescribeAPIForHover?)
    end
  end

  struct LSPDefinitionResponse
    include JSON::Serializable

    getter jsonrpc : String = "2.0"
    @[JSON::Field(emit_null: true)]
    getter id : Int64 | String | Nil
    @[JSON::Field(key: "result", emit_null: true)]
    getter list_of_locations : Array(LSPLocation)?

    def initialize(@id : Int64 | String | Nil, @list_of_locations : Array(LSPLocation)?)
    end
  end
end
