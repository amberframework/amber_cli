require "compiler/crystal/syntax"

module AmberLSP::LibraryRulePacks::GrantTenancy::SourceNode
  def self.full_call_name(call : Crystal::Call) : String
    receiver_name = receiver_path_name(call.obj)
    return call.name unless receiver_name

    "#{receiver_name}.#{call.name}"
  end

  def self.model_name_for_receiver(node : Crystal::ASTNode?) : String?
    case node
    when Crystal::Path
      node.names.join("::")
    when Crystal::Call
      model_name_for_receiver(node.obj)
    else
      nil
    end
  end

  def self.literal_name(node : Crystal::ASTNode?) : String?
    case node
    when Crystal::SymbolLiteral
      node.value
    when Crystal::StringLiteral
      node.value
    when Crystal::Path
      node.names.last?
    when Crystal::Var
      node.name
    else
      nil
    end
  end

  def self.default_table_name(class_name : String) : String
    characters = class_name.chars

    String.build do |table_name|
      characters.each_with_index do |character, character_index|
        previous_character = character_index > 0 ? characters[character_index - 1] : nil
        next_character = characters[character_index + 1]?
        starts_new_word = character_is_uppercase?(character) && previous_character &&
                          (character_is_lowercase_or_digit?(previous_character) ||
                           (character_is_uppercase?(previous_character) && next_character && character_is_lowercase?(next_character)))

        table_name << '_' if starts_new_word && !table_name.empty?
        table_name << character.downcase
      end
    end
  end

  private def self.receiver_path_name(node : Crystal::ASTNode?) : String?
    case node
    when Crystal::Path
      node.names.join("::")
    when Crystal::Call
      receiver_name = receiver_path_name(node.obj)
      return node.name unless receiver_name

      "#{receiver_name}.#{node.name}"
    else
      nil
    end
  end

  private def self.character_is_uppercase?(character : Char) : Bool
    character >= 'A' && character <= 'Z'
  end

  private def self.character_is_lowercase?(character : Char) : Bool
    character >= 'a' && character <= 'z'
  end

  private def self.character_is_lowercase_or_digit?(character : Char) : Bool
    character_is_lowercase?(character) || (character >= '0' && character <= '9')
  end
end
