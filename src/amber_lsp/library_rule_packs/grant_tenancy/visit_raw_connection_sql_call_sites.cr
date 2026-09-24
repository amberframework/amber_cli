require "compiler/crystal/syntax"

module AmberLSP::LibraryRulePacks::GrantTenancy
  class VisitRawConnectionSqlCallSites < Crystal::Visitor
    struct Occurrence
      getter call : Crystal::Call
      getter sql_literal : Crystal::StringLiteral

      def initialize(@call : Crystal::Call, @sql_literal : Crystal::StringLiteral)
      end
    end

    getter list_of_raw_connection_sql_call_sites : Array(Occurrence)

    @list_of_active_database_handle_names = [] of String
    @list_of_block_handle_scope_sizes = [] of Int32

    def initialize(@project_state : AmberLSP::LibraryRulePacks::DetermineProjectRulePackState)
      @list_of_raw_connection_sql_call_sites = [] of Occurrence
    end

    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    def visit(node : Crystal::Block) : Bool
      list_of_new_handle_names = [] of String
      if adapter_open_call?(node.call)
        node.args.each { |argument| list_of_new_handle_names << argument.name }
      end

      @list_of_active_database_handle_names.concat(list_of_new_handle_names)
      @list_of_block_handle_scope_sizes << list_of_new_handle_names.size
      true
    end

    def end_visit(node : Crystal::Block) : Nil
      added_handle_count = @list_of_block_handle_scope_sizes.pop?
      return unless added_handle_count && added_handle_count > 0

      @list_of_active_database_handle_names = @list_of_active_database_handle_names[0,
        @list_of_active_database_handle_names.size - added_handle_count]
    end

    def visit(node : Crystal::Call) : Bool
      return true unless raw_connection_sql_call?(node)

      sql_literal = node.args.first?.as?(Crystal::StringLiteral)
      return true unless sql_literal
      return true unless sql_literal_names_tenant_table?(sql_literal.value)

      @list_of_raw_connection_sql_call_sites << Occurrence.new(node, sql_literal)
      true
    end

    private def raw_connection_sql_call?(call : Crystal::Call) : Bool
      if {"exec", "query", "scalar"}.includes?(call.name)
        return database_handle_call?(call.obj)
      end

      if {"execute", "exec_query", "select_all", "select_one", "select_value",
          "select_values", "select_rows", "with_result_set"}.includes?(call.name)
        return grant_connection_facade_call?(call)
      end

      false
    end

    private def database_handle_call?(node : Crystal::ASTNode?) : Bool
      if node.is_a?(Crystal::Var)
        return @list_of_active_database_handle_names.includes?(node.name)
      end

      false
    end

    private def grant_connection_facade_call?(call : Crystal::Call) : Bool
      receiver_call = call.obj.as?(Crystal::Call)
      return false unless receiver_call

      receiver_call.name == "connection" &&
        SourceNode.full_call_name(receiver_call) == "Grant.connection"
    end

    private def adapter_open_call?(call : Crystal::Call?) : Bool
      return false unless call
      return false unless call.name == "open"

      receiver_has_adapter_call?(call.obj) || receiver_has_connection_registry_path?(call.obj)
    end

    private def receiver_has_adapter_call?(node : Crystal::ASTNode?) : Bool
      case node
      when Crystal::Call
        node.name == "adapter" || receiver_has_adapter_call?(node.obj)
      when Crystal::Var
        node.name == "adapter"
      else
        false
      end
    end

    private def receiver_has_connection_registry_path?(node : Crystal::ASTNode?) : Bool
      case node
      when Crystal::Path
        node.names == ["Grant", "Connections"]
      when Crystal::Call
        receiver_has_connection_registry_path?(node.obj) ||
          node.args.any? { |argument| receiver_has_connection_registry_path?(argument) }
      else
        false
      end
    end

    private def sql_literal_names_tenant_table?(sql_literal : String) : Bool
      list_of_sql_tokens = sql_literal.downcase.split(/[^a-z0-9_]+/)
      @project_state.list_of_row_tenant_table_names.any? do |table_name|
        normalized_table_name = table_name.split('.').last
        normalized_table_name && list_of_sql_tokens.includes?(normalized_table_name.downcase)
      end
    end
  end
end
