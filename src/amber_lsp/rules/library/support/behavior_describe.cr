require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Holds one parsed method behavior describe and its source.
  struct BehaviorDescribe
    getter selector : String
    getter source_code : String
    getter node : Crystal::Call

    # Initializes the describe record with its selector, source, and AST node.
    def initialize(@selector : String, @source_code : String, @node : Crystal::Call)
    end

    # Builds the collar shape for this describe.
    def shape : CollaredSpecShape
      CollaredSpecShape.new(@source_code, @node)
    end
  end
end
