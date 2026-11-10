require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Indexes method definitions, visibility, behavior, and calls from one source file.
  class IndexMethodsFromSource < Crystal::Visitor
    getter list_of_method_definitions = [] of MethodDefinition

    # Initializes the indexer with source, path, and changed-line information.
    def initialize(
      @root_node : Crystal::ASTNode,
      @relative_path : String,
      @source_code : String,
      @changed_lines : GitChangedLines,
    )
      @source_annotations = ReadSourceAnnotations.new(@source_code)
      @list_of_enclosing_type_names = [] of String
      @list_of_type_visibility = [] of Bool
      @list_of_type_nodoc = [] of Bool
    end

    # Collects method definitions from *root_node*.
    def perform : ListOfMethodDefinitions
      @root_node.accept(self)
      list_of_method_definitions
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # Applies explicit visibility before visiting its declaration.
    def visit(node : Crystal::VisibilityModifier) : Bool
      expression = node.exp
      if expression.is_a?(Crystal::Def) || expression.is_a?(Crystal::ClassDef) ||
         expression.is_a?(Crystal::ModuleDef) || expression.is_a?(Crystal::EnumDef)
        expression.visibility = node.modifier
      end
      true
    end

    # Tracks class and module names, visibility, and nodoc state.
    def visit(node : Crystal::ClassDef | Crystal::ModuleDef | Crystal::EnumDef) : Bool
      @list_of_enclosing_type_names << full_type_name(node.name)
      @list_of_type_visibility << node.visibility.public?
      has_nodoc = node.location.try { |location| @source_annotations.has_nodoc_comment_at?(location.line_number) } || false
      @list_of_type_nodoc << has_nodoc
      true
    end

    # Leaves the current type after its definitions are indexed.
    def end_visit(node : Crystal::ClassDef | Crystal::ModuleDef | Crystal::EnumDef) : Nil
      @list_of_enclosing_type_names.pop
      @list_of_type_visibility.pop
      @list_of_type_nodoc.pop
    end

    # Indexes a method and its receiverless or self calls.
    def visit(method_node : Crystal::Def) : Bool
      list_of_method_definitions << method_definition_for(method_node)
      true
    end

    private def method_definition_for(method_node : Crystal::Def) : MethodDefinition
      location = method_node.location
      end_location = method_node.end_location
      method_changed = if location && end_location
                         @changed_lines.includes_any?(
                           @relative_path,
                           location.line_number,
                           end_location.line_number,
                         )
                       else
                         false
                       end
      has_nodoc_method = location.try { |method_location| @source_annotations.has_nodoc_comment_at?(method_location.line_number) } || false
      owner_type_name = @list_of_enclosing_type_names.last? || "Object"
      has_public_type = @list_of_type_visibility.all? { |has_public_visibility| has_public_visibility }
      has_nodoc_type = @list_of_type_nodoc.any? { |type_has_nodoc| type_has_nodoc }
      list_of_called_method_names = CollectCallsWithinMethodBody.new(method_node.body).perform
      method_has_behavior = CheckMethodForBehavior.new(method_node.body).perform?

      MethodDefinition.new(
        owner_type_name,
        method_node.name,
        method_node.visibility,
        @relative_path,
        @source_code,
        method_node,
        list_of_called_method_names,
        !method_node.receiver.nil?,
        method_changed,
        method_has_behavior,
        has_public_type,
        has_nodoc_type,
        has_nodoc_method,
      )
    end

    private def full_type_name(name_path : Crystal::Path) : String
      path_name = name_path.names.join("::")
      return path_name if name_path.global?
      return path_name if @list_of_enclosing_type_names.empty?

      enclosing_type_name = @list_of_enclosing_type_names.last
      return path_name if path_name.starts_with?("#{enclosing_type_name}::")

      "#{enclosing_type_name}::#{path_name}"
    end
  end
end
