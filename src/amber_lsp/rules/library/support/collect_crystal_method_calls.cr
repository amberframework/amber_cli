require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Collects method calls in a Crystal syntax tree.
  class CollectCrystalMethodCalls < Crystal::Visitor
    getter list_of_calls = [] of Crystal::Call

    # Initializes the collector with *root_node*.
    def initialize(@root_node : Crystal::ASTNode)
    end

    # Collects method calls from *root_node* and its descendants.
    def perform : ListOfCrystalCalls
      @root_node.accept(self)
      list_of_calls
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # :nodoc:
    def visit(node : Crystal::Call) : Bool
      list_of_calls << node
      true
    end
  end
end
