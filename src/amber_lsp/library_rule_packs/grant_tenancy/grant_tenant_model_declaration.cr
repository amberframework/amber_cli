require "compiler/crystal/syntax"

module AmberLSP::LibraryRulePacks::GrantTenancy
  class GrantTenantModelDeclaration
    getter qualified_model_name : String
    getter class_name : String
    getter superclass_reference_name : String?
    getter source_table_name : String
    getter tenant_column_name : String?
    getter list_of_column_declarations : Array(Tuple(String, Crystal::ASTNode))
    getter? has_multitenant_macro : Bool
    getter? schema_tenant_excluded : Bool

    def initialize(
      @qualified_model_name : String,
      @class_name : String,
      @superclass_reference_name : String?,
    )
      @source_table_name = SourceNode.default_table_name(@class_name)
      @tenant_column_name = nil
      @list_of_column_declarations = [] of Tuple(String, Crystal::ASTNode)
      @has_multitenant_macro = false
      @schema_tenant_excluded = false
    end

    def capture_multitenant_column(column_name : String?) : Nil
      @has_multitenant_macro = true
      @tenant_column_name = column_name
    end

    def mark_schema_tenant_excluded : Nil
      @schema_tenant_excluded = true
    end

    def set_source_table_name(table_name : String) : Nil
      @source_table_name = table_name
    end

    def add_column_declaration(column_name : String, source_node : Crystal::ASTNode) : Nil
      @list_of_column_declarations << {column_name, source_node}
    end

    def grant_model? : Bool
      has_multitenant_macro? || schema_tenant_excluded? ||
        !@list_of_column_declarations.empty? ||
        @superclass_reference_name == "Grant::Base" ||
        @source_table_name != SourceNode.default_table_name(@class_name)
    end
  end
end
