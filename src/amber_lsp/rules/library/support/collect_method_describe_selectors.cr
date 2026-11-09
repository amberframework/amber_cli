require "compiler/crystal/syntax"
require "set"

module AmberLSP::Rules::Library::Support
  # Collects instance and class method selectors from spec syntax trees.
  class CollectMethodDescribeSelectors < Crystal::Visitor
    getter list_of_selectors = Set(String).new

    # Initializes the collector with *root_node*.
    def initialize(@root_node : Crystal::ASTNode)
    end

    # Collects method selectors from *root_node* and its descendants.
    def perform : SetOfMethodDescribeSelectors
      @root_node.accept(self)
      list_of_selectors
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # :nodoc:
    def visit(node : Crystal::Call) : Bool
      if selector = ReadBehaviorSelector.new(node).perform
        list_of_selectors << selector
      end
      true
    end
  end
end
