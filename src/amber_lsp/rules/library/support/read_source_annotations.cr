module AmberLSP::Rules::Library::Support
  # Reads line comments that mark source declarations as internal or exempt.
  class ReadSourceAnnotations
    # Initializes the reader with *content*.
    def initialize(@content : String)
    end

    # Returns whether a declaration at *line_number* has a preceding nodoc comment.
    def has_nodoc_comment_at?(line_number : Int32) : Bool
      line_index = line_number - 2
      while line_index >= 0
        source_line = @content.lines[line_index]?.try(&.strip)
        return false unless source_line && source_line.starts_with?("#")
        return true if source_line.includes?(":nodoc:")

        line_index -= 1
      end
      false
    end

    # Returns a collar exemption reason immediately above *line_number*.
    def collar_exemption_reason_at(line_number : Int32) : String?
      line_index = line_number - 2
      return if line_index < 0
      return unless source_line = @content.lines[line_index]?

      comment_parts = source_line.strip.split(',', 2)
      return unless comment_parts.size == 2
      return unless comment_parts[0].strip == "# collar: none"

      comment_parts[1].strip
    end
  end
end
