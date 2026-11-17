require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Holds one parsed method behavior describe and its source.
  struct BehaviorDescribe
    getter selector : String
    getter source_code : String
    getter node : Crystal::Call
    getter owner_type_name : String?

    # Initializes the describe record with its selector, source, and AST node.
    def initialize(
      @selector : String,
      @source_code : String,
      @node : Crystal::Call,
      @owner_type_name : String? = nil,
    )
    end

    # Returns whether this describe can cover a method on *method_owner_type_name*.
    #
    # A describe with no enclosing type could cover any owner. An unqualified
    # name such as `Widget` covers `Sample::Widget`; a qualified name covers only
    # the type it names.
    def covers_owner?(method_owner_type_name : String) : Bool
      return true unless describe_owner = @owner_type_name

      return describe_owner == method_owner_type_name if describe_owner.includes?("::")

      describe_owner == method_owner_type_name ||
        method_owner_type_name.ends_with?("::#{describe_owner}")
    end

    # Builds the collar shape for this describe.
    def shape : CollaredSpecShape
      CollaredSpecShape.new(@source_code, @node)
    end
  end
end
