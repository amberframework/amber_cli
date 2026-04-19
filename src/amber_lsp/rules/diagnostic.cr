require "json"

module AmberLSP::Rules
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

    def to_lsp_json : Hash(String, JSON::Any)
      {
        "range" => JSON::Any.new({
          "start" => JSON::Any.new({
            "line"      => JSON::Any.new(@range.start.line.to_i64),
            "character" => JSON::Any.new(@range.start.character.to_i64),
          }),
          "end" => JSON::Any.new({
            "line"      => JSON::Any.new(@range.end.line.to_i64),
            "character" => JSON::Any.new(@range.end.character.to_i64),
          }),
        }),
        "severity" => JSON::Any.new(@severity.value.to_i64),
        "code"     => JSON::Any.new(@code),
        "source"   => JSON::Any.new(@source),
        "message"  => JSON::Any.new(@message),
      }
    end
  end
end
