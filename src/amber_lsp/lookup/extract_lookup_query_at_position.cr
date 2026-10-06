module AmberLSP::Lookup
  struct LookupAtQuery
    getter query : String
    getter token : String
    getter receiver : String?

    def initialize(@query : String, @token : String, @receiver : String?)
    end
  end

  class ExtractLookupQueryAtPosition
    def initialize(@source : String, @line_number : Int32, @column_number : Int32)
    end

    def perform : LookupAtQuery?
      return nil if @line_number < 0 || @column_number < 0

      line = @source.lines[@line_number]?.try(&.rstrip("\r\n"))
      return nil unless line

      column = byte_offset_for_utf16_column(line, @column_number)
      before_cursor = line.byte_slice(0, column)
      after_cursor = line.byte_slice(column, line.bytesize - column)
      left_token = before_cursor.match(/[A-Za-z0-9_!?]+\z/).try(&.[0]) || ""
      right_token = after_cursor.match(/\A[A-Za-z0-9_!?]+/).try(&.[0]) || ""
      token = left_token + right_token
      return nil if token.empty?

      receiver_prefix = before_cursor.byte_slice(0, before_cursor.bytesize - left_token.bytesize)
      receiver_match = receiver_prefix.match(/([A-Za-z0-9_:@.!?()\[\]]+)([.#])\s*\z/)
      return LookupAtQuery.new(token, token, nil) unless receiver_match

      receiver = receiver_match[1].strip
      separator = receiver_match[2]
      if constant_receiver?(receiver)
        LookupAtQuery.new("#{receiver}#{separator}#{token}", token, receiver)
      else
        LookupAtQuery.new(token, token, receiver)
      end
    end

    private def constant_receiver?(receiver : String) : Bool
      receiver.matches?(/\A(?:::)?[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*(?:\([A-Za-z0-9_:, ?|&]+\))?\z/)
    end

    private def byte_offset_for_utf16_column(line : String, column_number : Int32) : Int32
      current_utf16_column = 0
      byte_offset = 0

      line.each_char do |character|
        break if current_utf16_column >= column_number

        character_utf16_width = character.ord > 0xFFFF_u32 ? 2 : 1
        break if current_utf16_column + character_utf16_width > column_number

        current_utf16_column += character_utf16_width
        byte_offset += character.to_s.bytesize
      end

      byte_offset
    end
  end
end
