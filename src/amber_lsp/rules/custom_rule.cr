module AmberLSP::Rules
  class CustomRule < BaseRule
    getter id : String
    getter description : String
    getter default_severity : Severity
    getter applies_to : Array(String)

    @pattern : Regex
    @message_template : String
    @negate : Bool

    def initialize(
      @id : String,
      @description : String,
      @default_severity : Severity,
      @applies_to : Array(String),
      @pattern : Regex,
      @message_template : String,
      @negate : Bool = false,
    )
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      return [] of Diagnostic unless applies_to.any? { |pattern|
                                       RuleRegistry.file_matches_pattern?(file_path, pattern)
                                     }

      if @negate
        check_negated(content)
      else
        check_positive(content)
      end
    end

    private def check_positive(content : String) : Array(Diagnostic)
      diagnostics = [] of Diagnostic

      content.each_line.with_index do |line, index|
        if match = @pattern.match(line)
          start_char = (match.begin(0) || 0).to_i32
          end_char = (match.end(0) || line.size).to_i32

          range = TextRange.new(
            Position.new(index.to_i32, start_char),
            Position.new(index.to_i32, end_char)
          )

          message = substitute_captures(@message_template, match)
          diagnostics << Diagnostic.new(range, @default_severity, @id, message)
        end
      end

      diagnostics
    end

    private def check_negated(content : String) : Array(Diagnostic)
      content.each_line.with_index do |line, _index|
        return [] of Diagnostic if @pattern.match(line)
      end

      # Pattern was not found anywhere in the file -- report at line 0
      range = TextRange.new(
        Position.new(0_i32, 0_i32),
        Position.new(0_i32, 0_i32)
      )

      [Diagnostic.new(range, @default_severity, @id, @message_template)]
    end

    private def substitute_captures(template : String, match : Regex::MatchData) : String
      message = template
      match.size.times do |i|
        if capture = match[i]?
          message = message.gsub("{#{i}}", capture)
        end
      end
      message
    end
  end
end
