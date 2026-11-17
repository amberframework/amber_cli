require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Checks whether a method body contains branching or error-handling behavior.
  class CheckMethodForBehavior < Crystal::Visitor
    getter? found = false

    # Initializes the checker with *method_body*.
    def initialize(@method_body : Crystal::ASTNode)
    end

    # Returns whether *method_body* contains a behavior branch.
    def perform? : Bool
      @method_body.accept(self)
      found?
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # :nodoc:
    def visit(node : Crystal::If | Crystal::Unless | Crystal::Case | Crystal::While | Crystal::Until | Crystal::Rescue | Crystal::ExceptionHandler | Crystal::And | Crystal::Or) : Bool
      @found = true
      false
    end

    # :nodoc:
    def visit(node : Crystal::Call) : Bool
      if node.obj.nil? && node.name == "raise"
        @found = true
        return false
      end

      true
    end
  end
end
