require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Collects unchecked cast nodes from a Crystal syntax tree.
  class CollectTypeCasts < Crystal::Visitor
    getter list_of_type_casts = [] of Crystal::Cast

    # Initializes the collector with *root_node*.
    def initialize(@root_node : Crystal::ASTNode)
    end

    # Collects casts from *root_node* and its descendants.
    def perform : ListOfTypeCasts
      @root_node.accept(self)
      list_of_type_casts
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # :nodoc:
    def visit(node : Crystal::Cast) : Bool
      list_of_type_casts << node
      true
    end
  end
end
