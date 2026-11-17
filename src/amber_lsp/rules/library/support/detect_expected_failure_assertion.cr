require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Detects expected-failure assertions in a just-past-the-boundary context.
  class DetectExpectedFailureAssertion < Crystal::Visitor
    EXPECTED_FAILURE_CALLS = %w[expect_raises should_not be_nil be_false be_empty]

    getter? found = false

    # Initializes the detector with *context_body*.
    def initialize(@context_body : Crystal::ASTNode)
    end

    # Returns whether *context_body* contains an expected-failure assertion.
    def perform? : Bool
      @context_body.accept(self)
      found?
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # :nodoc:
    def visit(node : Crystal::Call) : Bool
      if EXPECTED_FAILURE_CALLS.includes?(node.name)
        @found = true
        return false
      end

      true
    end
  end
end
