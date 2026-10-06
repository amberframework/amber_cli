require "./parse_api_type_name"

module AmberLSP::Lookup
  class APITypeParameterBindings
    def initialize(@type_template_name : String, @instantiated_type_name : String)
    end

    def perform : Hash(String, String)
      template_type = ParseAPITypeName.new(@type_template_name).perform
      instantiated_type = ParseAPITypeName.new(@instantiated_type_name).perform
      return {} of String => String unless template_type.base_name == instantiated_type.base_name
      return {} of String => String unless template_type.list_of_type_arguments.size == instantiated_type.list_of_type_arguments.size

      bindings = {} of String => String
      template_type.list_of_type_arguments.each_with_index do |parameter_name, index|
        argument = instantiated_type.list_of_type_arguments[index]?
        bindings[parameter_name] = argument if argument
      end
      bindings
    end

    def substitute(type_expression : String) : String
      bindings = perform
      return type_expression if bindings.empty?

      output = String::Builder.new
      current_token = String::Builder.new
      type_expression.each_char do |character|
        if type_token_character?(character)
          current_token << character
        else
          append_substituted_token(output, current_token, bindings)
          current_token = String::Builder.new
          output << character
        end
      end
      append_substituted_token(output, current_token, bindings)
      output.to_s
    end

    private def type_token_character?(character : Char) : Bool
      (character >= 'A' && character <= 'Z') ||
        (character >= 'a' && character <= 'z') ||
        (character >= '0' && character <= '9') ||
        character == '_' || character == ':'
    end

    private def append_substituted_token(
      output : String::Builder,
      current_token : String::Builder,
      bindings : Hash(String, String),
    ) : Nil
      token = current_token.to_s
      output << (bindings[token]? || token)
    end
  end

  class ResolveAPIIndexReturnType
    def initialize(
      @declared_return_type : String,
      @receiver_type : String?,
      @owner_type_name : String? = nil,
      @additional_type_parameter_bindings : Hash(String, String) = {} of String => String,
    )
    end

    def perform : String
      return UNKNOWN_API_RETURN_TYPE if @declared_return_type == UNKNOWN_API_RETURN_TYPE

      resolved_type = @declared_return_type
      if receiver_type = @receiver_type
        resolved_type = resolved_type.gsub(/\bself\b/) { receiver_type }
      end

      resolved_type = substitute_owner_type_parameters(resolved_type)
      resolved_type = expand_nilable_types(resolved_type)
      resolved_type = resolved_type.gsub("::Nil", "Nil")
      resolved_type = resolved_type.gsub(/\s+or\s+/, " | ")
      normalize_union_order(resolved_type)
    end

    private def substitute_owner_type_parameters(return_type : String) : String
      owner_type_name = @owner_type_name
      receiver_type = @receiver_type
      bindings = @additional_type_parameter_bindings.dup
      if owner_type_name && receiver_type
        owner_bindings = APITypeParameterBindings.new(owner_type_name, receiver_type).perform
        bindings.merge!(owner_bindings)
      end
      return return_type if bindings.empty?

      substitute_type_tokens(return_type, bindings)
    end

    private def substitute_type_tokens(return_type : String, bindings : Hash(String, String)) : String
      output = String::Builder.new
      current_token = String::Builder.new

      return_type.each_char do |character|
        if type_token_character?(character)
          current_token << character
        else
          append_substituted_token(output, current_token, bindings)
          current_token = String::Builder.new
          output << character
        end
      end
      append_substituted_token(output, current_token, bindings)
      output.to_s
    end

    private def type_token_character?(character : Char) : Bool
      (character >= 'A' && character <= 'Z') ||
        (character >= 'a' && character <= 'z') ||
        (character >= '0' && character <= '9') ||
        character == '_' || character == ':'
    end

    private def append_substituted_token(
      output : String::Builder,
      current_token : String::Builder,
      bindings : Hash(String, String),
    ) : Nil
      token = current_token.to_s
      output << (bindings[token]? || token)
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
