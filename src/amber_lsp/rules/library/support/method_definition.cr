require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Holds one method, its owner type, visibility, source, and local calls.
  struct MethodDefinition
    getter owner_type_name : String
    getter method_name : String
    getter visibility : Crystal::Visibility
    getter relative_path : String
    getter source_code : String
    getter method_node : Crystal::Def
    getter list_of_called_method_names : ListOfStrings
    getter? class_method = false
    getter? changed = false
    getter? has_behavior = false
    getter? has_public_type = false
    getter? has_nodoc_type = false
    getter? has_nodoc_method = false

    # Initializes the method record with its parsed declaration and context.
    def initialize(
      @owner_type_name : String,
      @method_name : String,
      @visibility : Crystal::Visibility,
      @relative_path : String,
      @source_code : String,
      @method_node : Crystal::Def,
      @list_of_called_method_names : ListOfStrings,
      @class_method : Bool,
      @changed : Bool,
      @has_behavior : Bool,
      @has_public_type : Bool,
      @has_nodoc_type : Bool,
      @has_nodoc_method : Bool,
    )
    end

    # Returns the describe selector for this method.
    def selector : String
      return ".new" if method_name == "initialize"
      return ".#{method_name}" if class_method?

      "##{method_name}"
    end

    # Returns the key used to merge reopened type methods in the call graph.
    def method_key : String
      method_kind = class_method? ? "class" : "instance"
      "#{owner_type_name}::#{method_kind}::#{method_name}"
    end

    # Returns a source-unique identity for this declaration.
    def definition_identity : String
      line_number = method_node.location.try(&.line_number) || 0
      "#{relative_path}:#{line_number}:#{method_key}"
    end

    # Returns whether this is a public method callers can expose in specs.
    def public_caller? : Bool
      has_public_type? && !has_nodoc_type? && visibility.public? && !has_nodoc_method?
    end

    # Returns whether this is a private or protected implementation method.
    def private_or_protected? : Bool
      visibility.private? || visibility.protected?
    end

    # Returns whether this changed behavior needs collars. A `:nodoc:` method is internal,
    # like a private one, so it is reached through its public callers.
    def changed_behavior_method? : Bool
      changed? && has_behavior? && has_public_type?
    end
  end

  alias ListOfMethodDefinitions = Array(MethodDefinition)
end
