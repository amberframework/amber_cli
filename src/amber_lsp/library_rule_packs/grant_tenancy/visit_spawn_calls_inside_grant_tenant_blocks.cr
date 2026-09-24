require "compiler/crystal/syntax"

module AmberLSP::LibraryRulePacks::GrantTenancy
  class VisitSpawnCallsInsideGrantTenantBlocks < Crystal::Visitor
    getter list_of_spawn_calls_inside_tenant_blocks : Array(Crystal::Call)

    @tenant_block_depth = 0
    @list_of_block_scope_changes = [] of Bool
    @list_of_method_scope_snapshots = [] of Int32
    @macro_depth = 0

    def initialize
      @list_of_spawn_calls_inside_tenant_blocks = [] of Crystal::Call
    end

    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    def visit(node : Crystal::Def) : Bool
      @list_of_method_scope_snapshots << @tenant_block_depth
      @tenant_block_depth = 0
      true
    end

    def end_visit(node : Crystal::Def) : Nil
      previous_scope_depth = @list_of_method_scope_snapshots.pop?
      @tenant_block_depth = previous_scope_depth if previous_scope_depth
    end

    def visit(node : Crystal::Macro) : Bool
      @macro_depth += 1
      true
    end

    def end_visit(node : Crystal::Macro) : Nil
      @macro_depth -= 1
    end

    def visit(node : Crystal::Block) : Bool
      call_is_tenant_scope = node.call.try do |block_call|
        {"Grant::Tenant.with", "Grant::SchemaTenant.with"}.includes?(SourceNode.full_call_name(block_call))
      end || false
      enters_tenant_scope = call_is_tenant_scope && @macro_depth == 0
      @tenant_block_depth += 1 if enters_tenant_scope
      @list_of_block_scope_changes << enters_tenant_scope
      true
    end

    def end_visit(node : Crystal::Block) : Nil
      scope_change = @list_of_block_scope_changes.pop?
      @tenant_block_depth -= 1 if scope_change
    end

    def visit(node : Crystal::Call) : Bool
      if node.name == "spawn" && @tenant_block_depth > 0 && @macro_depth == 0
        @list_of_spawn_calls_inside_tenant_blocks << node
      end
      true
    end
  end
end
