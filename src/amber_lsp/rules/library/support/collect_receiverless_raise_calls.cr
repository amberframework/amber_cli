require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Collects receiverless raise calls from a Crystal AST.
  class CollectReceiverlessRaiseCalls < Crystal::Visitor
    getter list_of_raise_calls = [] of Crystal::Call

    # Initializes the collector with *root_node*.
    def initialize(@root_node : Crystal::ASTNode)
    end

    # Collects receiverless raise calls from *root_node* and its descendants.
    def perform : ListOfCrystalCalls
      @root_node.accept(self)
      list_of_raise_calls
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # :nodoc:
    def visit(node : Crystal::Call) : Bool
      list_of_raise_calls << node if node.obj.nil? && node.name == "raise"
      true
    end
  end
end
