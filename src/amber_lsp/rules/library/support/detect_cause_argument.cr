require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Detects a named cause argument in a Crystal AST.
  class DetectCauseArgument < Crystal::Visitor
    getter? found_cause_argument = false

    # Initializes the detector with *root_node*.
    def initialize(@root_node : Crystal::ASTNode)
    end

    # Returns whether *root_node* contains a `cause:` argument.
    def perform? : Bool
      @root_node.accept(self)
      found_cause_argument?
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # :nodoc:
    def visit(node : Crystal::NamedArgument) : Bool
      if node.name == "cause"
        @found_cause_argument = true
        return false
      end

      true
    end
  end
end
