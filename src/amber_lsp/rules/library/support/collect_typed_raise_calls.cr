require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Collects receiverless raises with string messages outside compile-time macros.
  class CollectTypedRaiseCalls < Crystal::Visitor
    getter list_of_raise_calls = [] of Crystal::Call

    # Initializes the collector with *root_node*.
    def initialize(@root_node : Crystal::ASTNode)
    end

    # Collects eligible receiverless raise calls from *root_node*.
    def perform : ListOfCrystalCalls
      @root_node.accept(self)
      list_of_raise_calls
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # Skips macro expressions because they run during compilation.
    def visit(node : Crystal::MacroExpression) : Bool
      false
    end

    # :nodoc:
    def visit(node : Crystal::Call) : Bool
      list_of_raise_calls << node if node.obj.nil? && node.name == "raise"
      true
    end
  end
end
