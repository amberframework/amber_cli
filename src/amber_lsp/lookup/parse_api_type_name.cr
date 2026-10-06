module AmberLSP::Lookup
  struct ParsedAPITypeName
    getter base_name : String
    getter list_of_type_arguments : Array(String)

    def initialize(@base_name : String, @list_of_type_arguments : Array(String))
    end
  end

  class ParseAPITypeName
    def initialize(@name : String)
    end

    def perform : ParsedAPITypeName
      opening_index = @name.index('(')
      return ParsedAPITypeName.new(@name.strip, [] of String) unless opening_index && @name.ends_with?(')')

      generic_arguments = @name.byte_slice(opening_index + 1, @name.bytesize - opening_index - 2)
      ParsedAPITypeName.new(
        @name.byte_slice(0, opening_index).strip,
        split_type_arguments(generic_arguments),
      )
    end

    private def split_type_arguments(generic_arguments : String) : Array(String)
      list_of_arguments = [] of String
      current_argument = String::Builder.new
      nesting_depth = 0

      generic_arguments.each_char do |character|
        case character
        when '(' then nesting_depth += 1
        when ')' then nesting_depth -= 1 if nesting_depth > 0
        when ','
          if nesting_depth == 0
            append_argument(list_of_arguments, current_argument)
            current_argument = String::Builder.new
            next
          end
        end
        current_argument << character
      end
      append_argument(list_of_arguments, current_argument)
      list_of_arguments
    end

    private def append_argument(list_of_arguments : Array(String), current_argument : String::Builder) : Nil
      argument = current_argument.to_s.strip
      list_of_arguments << argument unless argument.empty?
    end
  end
end
