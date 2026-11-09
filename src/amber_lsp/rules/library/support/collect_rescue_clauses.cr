require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Collects rescue clauses from a Crystal syntax tree.
  class CollectRescueClauses < Crystal::Visitor
    getter list_of_rescue_clauses = [] of Crystal::Rescue

    # Initializes the collector with *root_node*.
    def initialize(@root_node : Crystal::ASTNode)
    end

    # Collects rescue clauses from *root_node* and its descendants.
    def perform : ListOfRescueClauses
      @root_node.accept(self)
      list_of_rescue_clauses
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # :nodoc:
    def visit(node : Crystal::Rescue) : Bool
      list_of_rescue_clauses << node
      true
    end
  end
end
