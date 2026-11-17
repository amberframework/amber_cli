require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Collects documented public method definitions from a Crystal AST.
  class CollectPublicMethods < Crystal::Visitor
    getter list_of_methods = [] of Crystal::Def

    # Initializes the collector with *root_node* and its source text.
    def initialize(@root_node : Crystal::ASTNode, @content : String)
      @source_annotations = ReadSourceAnnotations.new(@content)
      @list_of_type_visibility = [] of Bool
      @list_of_type_nodoc = [] of Bool
    end

    # Collects documented public methods from *root_node*.
    def perform : ListOfPublicMethods
      @root_node.accept(self)
      list_of_methods
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # Applies explicit visibility to a declaration before visiting it.
    def visit(node : Crystal::VisibilityModifier) : Bool
      expression = node.exp
      if expression.is_a?(Crystal::Def) || expression.is_a?(Crystal::ClassDef) ||
         expression.is_a?(Crystal::ModuleDef) || expression.is_a?(Crystal::EnumDef)
        expression.visibility = node.modifier
      end
      true
    end

    # Tracks visibility and nodoc comments for nested types.
    def visit(node : Crystal::ClassDef | Crystal::ModuleDef | Crystal::EnumDef) : Bool
      @list_of_type_visibility << node.visibility.public?
      has_nodoc = node.location.try { |location| @source_annotations.has_nodoc_comment_at?(location.line_number) } || false
      @list_of_type_nodoc << has_nodoc
      true
    end

    # :nodoc:
    def end_visit(node : Crystal::ClassDef | Crystal::ModuleDef | Crystal::EnumDef) : Nil
      @list_of_type_visibility.pop
      @list_of_type_nodoc.pop
    end

    # Collects methods that remain public through every containing type.
    def visit(method_node : Crystal::Def) : Bool
      if public_method?(method_node)
        list_of_methods << method_node
      end
      true
    end

    private def public_method?(method_node : Crystal::Def) : Bool
      return false unless method_node.visibility.public?
      return false unless @list_of_type_visibility.all? { |is_public| is_public }
      return false if @list_of_type_nodoc.any? { |has_nodoc| has_nodoc }
      return false unless location = method_node.location

      !@source_annotations.has_nodoc_comment_at?(location.line_number)
    end
  end
end
