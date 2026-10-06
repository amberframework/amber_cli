require "json"

module AmberLSP::Rules
  # :nodoc:
  struct LSPPosition
    include JSON::Serializable

    getter line : Int32
    getter character : Int32

    def initialize(@line : Int32, @character : Int32)
    end
  end

  # :nodoc:
  struct LSPRange
    include JSON::Serializable

    getter start : LSPPosition
    @[JSON::Field(key: "end")]
    getter end_position : LSPPosition

    def initialize(@start : LSPPosition, @end_position : LSPPosition)
    end
  end

  # :nodoc:
  struct LSPDiagnostic
    include JSON::Serializable

    getter range : LSPRange
    getter severity : Int32
    getter code : String
    getter source : String
    getter message : String

    def initialize(@range : LSPRange, @severity : Int32, @code : String, @source : String, @message : String)
    end
  end

  struct Position
    getter line : Int32
    getter character : Int32

    def initialize(@line : Int32, @character : Int32)
    end
  end

  struct TextRange
    getter start : Position
    getter end : Position

    def initialize(@start : Position, @end : Position)
    end
  end

  struct Diagnostic
    getter range : TextRange
    getter severity : Severity
    getter code : String
    getter source : String
    getter message : String

    def initialize(
      @range : TextRange,
      @severity : Severity,
      @code : String,
      @message : String,
      @source : String = "amber-lsp",
    )
    end

    def to_lsp_diagnostic : LSPDiagnostic
      lsp_range = LSPRange.new(
        LSPPosition.new(@range.start.line, @range.start.character),
        LSPPosition.new(@range.end.line, @range.end.character),
      )

      LSPDiagnostic.new(lsp_range, @severity.value, @code, @source, @message)
    end
  end
end
