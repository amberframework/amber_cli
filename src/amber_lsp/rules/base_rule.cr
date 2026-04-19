module AmberLSP::Rules
  abstract class BaseRule
    abstract def id : String
    abstract def description : String
    abstract def default_severity : Severity
    abstract def applies_to : Array(String)
    abstract def check(file_path : String, content : String) : Array(Diagnostic)

    # Finds the line and character range for the first occurrence of a pattern.
    # Returns nil if the pattern is not found.
    def find_line_range(content : String, pattern : Regex) : TextRange?
      content.each_line.with_index do |line, line_number|
        match = pattern.match(line)
        if match
          start_char = match.begin(0) || 0
          end_char = match.end(0) || line.size
          return TextRange.new(
            Position.new(line_number.to_i32, start_char.to_i32),
            Position.new(line_number.to_i32, end_char.to_i32)
          )
        end
      end
      nil
    end

    # Finds all line and character ranges for occurrences of a pattern.
    def find_all_line_ranges(content : String, pattern : Regex) : Array(TextRange)
      ranges = [] of TextRange
      content.each_line.with_index do |line, line_number|
        line.scan(pattern) do |match|
          start_char = match.begin(0) || 0
          end_char = match.end(0) || line.size
          ranges << TextRange.new(
            Position.new(line_number.to_i32, start_char.to_i32),
            Position.new(line_number.to_i32, end_char.to_i32)
          )
        end
      end
      ranges
    end
  end
end
