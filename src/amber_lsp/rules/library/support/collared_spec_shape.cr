require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Checks the direct golden and boundary cases in a method describe.
  class CollaredSpecShape
    MSG_BOUNDARY_CONTEXT      = "Add a context starting with `at the boundary`"
    MSG_PAST_BOUNDARY_CONTEXT = "Add a context starting with `just past the boundary`"
    MSG_GOLDEN_CASE           = "Add a direct golden `it` or `context` case"
    MSG_EXPECTED_FAILURE      = "Add an expected-failure assertion to the just-past-the-boundary context"
    MSG_EXEMPTION_REASON      = "Add a reason after `# collar: none,`"

    getter list_of_missing_parts = [] of String
    getter? has_valid_exemption = false

    # Initializes the shape checker with *source_code* and *describe_call*.
    def initialize(@source_code : String, @describe_call : Crystal::Call)
      if exemption_reason = collar_exemption_reason
        if exemption_reason.empty?
          list_of_missing_parts << MSG_EXEMPTION_REASON
        else
          @has_valid_exemption = true
          return
        end
      end

      check_shape
    end

    # Returns whether the describe has both collars and a golden case.
    def satisfied? : Bool
      has_valid_exemption? || list_of_missing_parts.empty?
    end

    private def collar_exemption_reason : String?
      return unless location = @describe_call.location

      line_index = location.line_number - 2
      return if line_index < 0
      return unless source_line = @source_code.lines[line_index]?

      comment_parts = source_line.strip.split(',', 2)
      return unless comment_parts.size == 2
      return unless comment_parts[0].strip == "# collar: none"

      comment_parts[1].strip
    end

    private def check_shape : Nil
      list_of_child_calls = direct_block_calls
      past_boundary_call = list_of_child_calls.find { |child_call| past_boundary_context?(child_call) }

      if !list_of_child_calls.any? { |child_call| boundary_context?(child_call) }
        list_of_missing_parts << MSG_BOUNDARY_CONTEXT
      end
      list_of_missing_parts << MSG_PAST_BOUNDARY_CONTEXT unless past_boundary_call
      list_of_missing_parts << MSG_GOLDEN_CASE unless golden_case_exists?(list_of_child_calls)
      if past_boundary_call && !expected_failure_assertion_exists?(past_boundary_call)
        list_of_missing_parts << MSG_EXPECTED_FAILURE
      end
    end

    private def direct_block_calls : Array(Crystal::Call)
      list_of_calls = [] of Crystal::Call
      return list_of_calls unless block_node = @describe_call.block

      body = block_node.body
      if expression_list = body.as?(Crystal::Expressions)
        expression_list.expressions.each do |expression|
          if expression.is_a?(Crystal::Call)
            list_of_calls << expression
          end
        end
      elsif body.is_a?(Crystal::Call)
        list_of_calls << body
      end
      list_of_calls
    end

    private def context_description(node : Crystal::Call) : String?
      return unless node.name == "context"
      return unless description_node = node.args.first?.try(&.as?(Crystal::StringLiteral))

      description_node.value
    end

    private def boundary_context?(node : Crystal::Call) : Bool
      context_description(node).try(&.starts_with?("at the boundary")) || false
    end

    private def past_boundary_context?(node : Crystal::Call) : Bool
      context_description(node).try(&.starts_with?("just past the boundary")) || false
    end

    private def expected_failure_assertion_exists?(context_call : Crystal::Call) : Bool
      return false unless block_node = context_call.block

      DetectExpectedFailureAssertion.new(block_node.body).perform?
    end

    private def golden_case_exists?(list_of_child_calls : Array(Crystal::Call)) : Bool
      list_of_child_calls.any? do |child_call|
        child_call.name == "it" || golden_context?(child_call)
      end
    end

    private def golden_context?(node : Crystal::Call) : Bool
      return false unless node.name == "context"
      return true unless description = context_description(node)

      !description.starts_with?("at the boundary") &&
        !description.starts_with?("just past the boundary")
    end
  end
end
