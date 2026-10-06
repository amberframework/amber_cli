module AmberLSP::Lookup
  class ResolveAPIIndexReturnType
    def initialize(@declared_return_type : String, @receiver_type : String?)
    end

    def perform : String
      return "unknown" if @declared_return_type == "unknown"

      resolved_type = @declared_return_type
      if receiver_type = @receiver_type
        resolved_type = resolved_type.gsub(/\bself\b/) { receiver_type }
      end

      resolved_type = expand_nilable_types(resolved_type)
      resolved_type = resolved_type.gsub("::Nil", "Nil")
      resolved_type = resolved_type.gsub(/\s+or\s+/, " | ")
      normalize_union_order(resolved_type)
    end

    private def expand_nilable_types(return_type : String) : String
      return_type.gsub(/([A-Za-z_][A-Za-z0-9_:]*(?:\([^?]*\))?)\?/) do |match|
        "#{match.byte_slice(0, match.bytesize - 1)} | Nil"
      end
    end

    private def normalize_union_order(return_type : String) : String
      list_of_types = [] of String
      current_type = String::Builder.new
      nesting_depth = 0

      return_type.each_char do |character|
        case character
        when '(' then nesting_depth += 1
        when ')' then nesting_depth -= 1 if nesting_depth > 0
        when '|'
          if nesting_depth == 0
            append_type(list_of_types, current_type)
            current_type = String::Builder.new
            next
          end
        end
        current_type << character
      end
      append_type(list_of_types, current_type)

      nil_type_present = list_of_types.any? { |type| type == "Nil" }
      return list_of_types.join(" | ") unless nil_type_present

      list_of_types.reject! { |type| type == "Nil" }
      list_of_types << "Nil"
      list_of_types.join(" | ")
    end

    private def append_type(list_of_types : Array(String), current_type : String::Builder) : Nil
      type = current_type.to_s.strip
      return if type.empty?
      return if list_of_types.includes?(type)

      list_of_types << type
    end
  end
end
