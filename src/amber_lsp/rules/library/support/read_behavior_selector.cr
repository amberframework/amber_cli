require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Reads an instance or class method selector from a describe call.
  class ReadBehaviorSelector
    # Initializes the selector reader with *describe_call*.
    def initialize(@describe_call : Crystal::Call)
    end

    # Returns the behavior selector or nil for other describes.
    def perform : String?
      return unless @describe_call.name == "describe"
      return unless description_node = @describe_call.args.first?.try(&.as?(Crystal::StringLiteral))

      description = description_node.value
      return unless description.starts_with?("#") || description.starts_with?(".")

      description
    end
  end
end
