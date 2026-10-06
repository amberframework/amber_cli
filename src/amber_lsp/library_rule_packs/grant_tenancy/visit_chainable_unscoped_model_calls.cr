require "compiler/crystal/syntax"

module AmberLSP::LibraryRulePacks::GrantTenancy
  class VisitChainableUnscopedModelCalls < Crystal::Visitor
    struct Occurrence
      getter call : Crystal::Call
      getter model_reference_name : String
      getter? has_bulk_write_after : Bool

      def initialize(@call : Crystal::Call, @model_reference_name : String, @has_bulk_write_after : Bool)
      end
    end

    getter list_of_chainable_unscoped_calls : Array(Occurrence)
    getter list_of_block_unscoped_calls : Array(Crystal::Call)

    @list_of_call_stack = [] of Crystal::Call

    def initialize(@project_state : AmberLSP::LibraryRulePacks::DetermineProjectRulePackState)
      @list_of_chainable_unscoped_calls = [] of Occurrence
      @list_of_block_unscoped_calls = [] of Crystal::Call
    end

    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    def visit(node : Crystal::Call) : Bool
      if node.name == "unscoped"
        if model_reference_name = SourceNode.model_name_for_receiver(node.obj)
          if @project_state.has_row_tenant_model?(model_reference_name)
            if node.block
              @list_of_block_unscoped_calls << node
            else
              @list_of_chainable_unscoped_calls << Occurrence.new(
                node,
                model_reference_name,
                has_bulk_write_after?(node, model_reference_name),
              )
            end
          end
        end
      end

      @list_of_call_stack << node
      true
    end

    def end_visit(node : Crystal::Call) : Nil
      @list_of_call_stack.pop
    end

    private def has_bulk_write_after?(unscoped_call : Crystal::Call, model_reference_name : String) : Bool
      @list_of_call_stack.any? do |parent_call|
        next false unless {"update_all", "delete_all"}.includes?(parent_call.name)

        parent_model_reference_name = SourceNode.model_name_for_receiver(parent_call.obj)
        next false unless parent_model_reference_name == model_reference_name

        receiver_chain_has_chainable_unscoped_call?(parent_call.obj)
      end
    end

    private def receiver_chain_has_chainable_unscoped_call?(node : Crystal::ASTNode?) : Bool
      case node
      when Crystal::Call
        (node.name == "unscoped" && node.block.nil?) || receiver_chain_has_chainable_unscoped_call?(node.obj)
      else
        false
      end
    end
  end
end
