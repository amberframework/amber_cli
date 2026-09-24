require "compiler/crystal/syntax"

module AmberLSP::LibraryRulePacks::GrantTenancy
  class VisitGrantSchemaQueriesOutsideTenantBlocks < Crystal::Visitor
    LIST_OF_QUERY_METHOD_NAMES = {
      "all", "where", "find", "find!", "find_by", "find_by!", "first", "first?",
      "last", "last?", "count", "exists?", "pluck", "sum", "average", "minimum", "maximum",
    }

    getter list_of_schema_queries_outside_tenant_blocks : Array(Crystal::Call)

    @schema_tenant_block_depth = 0
    @list_of_call_stack = [] of Crystal::Call
    @list_of_block_scope_changes = [] of Bool
    @list_of_method_scope_snapshots = [] of Int32

    def initialize(@project_state : AmberLSP::LibraryRulePacks::DetermineProjectRulePackState)
      @list_of_schema_queries_outside_tenant_blocks = [] of Crystal::Call
    end

    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    def visit(node : Crystal::Def) : Bool
      @list_of_method_scope_snapshots << @schema_tenant_block_depth
      @schema_tenant_block_depth = 0
      true
    end

    def end_visit(node : Crystal::Def) : Nil
      previous_scope_depth = @list_of_method_scope_snapshots.pop?
      @schema_tenant_block_depth = previous_scope_depth if previous_scope_depth
    end

    def visit(node : Crystal::Block) : Bool
      enters_schema_tenant_block = node.call.try do |block_call|
        SourceNode.full_call_name(block_call) == "Grant::SchemaTenant.with"
      end || false
      @schema_tenant_block_depth += 1 if enters_schema_tenant_block
      @list_of_block_scope_changes << enters_schema_tenant_block
      true
    end

    def end_visit(node : Crystal::Block) : Nil
      enters_schema_tenant_block = @list_of_block_scope_changes.pop?
      @schema_tenant_block_depth -= 1 if enters_schema_tenant_block
    end

    def visit(node : Crystal::Call) : Bool
      model_reference_name = SourceNode.model_name_for_receiver(node.obj)
      if model_reference_name &&
         LIST_OF_QUERY_METHOD_NAMES.includes?(node.name) &&
         @schema_tenant_block_depth == 0 &&
         @project_state.has_non_excluded_schema_model?(model_reference_name) &&
         !nested_inside_schema_model_query?(model_reference_name)
        @list_of_schema_queries_outside_tenant_blocks << node
      end

      @list_of_call_stack << node
      true
    end

    def end_visit(node : Crystal::Call) : Nil
      @list_of_call_stack.pop
    end

    private def nested_inside_schema_model_query?(model_reference_name : String) : Bool
      @list_of_call_stack.any? do |parent_call|
        next false unless LIST_OF_QUERY_METHOD_NAMES.includes?(parent_call.name)

        parent_model_reference_name = SourceNode.model_name_for_receiver(parent_call.obj)
        parent_model_reference_name == model_reference_name
      end
    end
  end
end
