require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Detects supported assertions in a spec example.
  class DetectSpecAssertion < Crystal::Visitor
    ASSERTION_METHOD_NAMES = %w[should should_not expect_raises fail]

    getter? found = false

    # Initializes the detector with *example_body* and assertion prefixes.
    def initialize(@example_body : Crystal::ASTNode, @list_of_assertion_prefixes : Array(String))
    end

    # Returns whether *example_body* contains a supported assertion.
    def perform? : Bool
      @example_body.accept(self)
      found?
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # :nodoc:
    def visit(node : Crystal::Call) : Bool
      if assertion_call?(node.name)
        @found = true
        return false
      end

      true
    end

    private def assertion_call?(call_name : String) : Bool
      return true if ASSERTION_METHOD_NAMES.includes?(call_name)

      @list_of_assertion_prefixes.any? do |prefix|
        !prefix.empty? && call_name.starts_with?(prefix)
      end
    end
  end
end
