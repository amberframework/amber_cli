require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Collects path constants from a Crystal AST.
  class CollectPathsFromCrystalAST < Crystal::Visitor
    getter list_of_paths = [] of Crystal::Path

    # Initializes the collector with *root_node*.
    def initialize(@root_node : Crystal::ASTNode)
    end

    # Collects paths from *root_node* and its descendants.
    def perform : ListOfCrystalPaths
      @root_node.accept(self)
      list_of_paths
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # :nodoc:
    def visit(node : Crystal::Path) : Bool
      list_of_paths << node
      true
    end
  end
end
