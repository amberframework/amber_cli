require "compiler/crystal/syntax"

module AmberLSP::LibraryRulePacks::GrantTenancy
  class VisitGrantTenantClearCalls < Crystal::Visitor
    getter list_of_tenant_clear_calls : Array(Crystal::Call)

    def initialize
      @list_of_tenant_clear_calls = [] of Crystal::Call
    end

    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    def visit(node : Crystal::Call) : Bool
      if SourceNode.full_call_name(node) == "Grant::Tenant.clear"
        @list_of_tenant_clear_calls << node
      end
      true
    end
  end
end
