require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Collects behavior describe calls from a Crystal syntax tree.
  class CollectBehaviorDescribes < Crystal::Visitor
    getter list_of_describes = [] of Crystal::Call

    # Initializes the collector with *root_node*.
    def initialize(@root_node : Crystal::ASTNode)
    end

    # Collects method behavior describes from *root_node*.
    def perform : ListOfCrystalCalls
      @root_node.accept(self)
      list_of_describes
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # :nodoc:
    def visit(node : Crystal::Call) : Bool
      list_of_describes << node if ReadBehaviorSelector.new(node).perform
      true
    end
  end
end
