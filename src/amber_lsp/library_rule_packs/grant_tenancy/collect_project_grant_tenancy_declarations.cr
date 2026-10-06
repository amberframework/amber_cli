require "compiler/crystal/syntax"

module AmberLSP::LibraryRulePacks::GrantTenancy
  class CollectProjectGrantTenancyDeclarations < Crystal::Visitor
    getter list_of_model_declarations : Array(GrantTenantModelDeclaration)
    getter? uses_row_tenancy : Bool
    getter? uses_schema_tenancy : Bool

    @list_of_model_stack = [] of GrantTenantModelDeclaration
    @list_of_namespace_segments = [] of String
    @list_of_namespace_stack_sizes = [] of Int32
    @method_depth = 0
    @macro_depth = 0
    @next_class_table_name : String?

    def initialize
      @list_of_model_declarations = [] of GrantTenantModelDeclaration
      @uses_row_tenancy = false
      @uses_schema_tenancy = false
    end

    def self.for_source(content : String) : CollectProjectGrantTenancyDeclarations
      collector = new
      collector.accept(Crystal::Parser.new(content).parse)
      collector
    rescue Crystal::SyntaxException
      new
    end

    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    def visit(node : Crystal::ModuleDef) : Bool
      @list_of_namespace_stack_sizes << @list_of_namespace_segments.size
      @list_of_namespace_segments.concat(node.name.names)
      true
    end

    def end_visit(node : Crystal::ModuleDef) : Nil
      restore_namespace_stack
    end

    def visit(node : Crystal::ClassDef) : Bool
      class_name = node.name.names.last
      qualified_model_name = if node.name.global?
                               node.name.names.join("::")
                             else
                               (@list_of_namespace_segments + node.name.names).join("::")
                             end
      superclass_reference_name = SourceNode.model_name_for_receiver(node.superclass)
      model_declaration = GrantTenantModelDeclaration.new(
        qualified_model_name,
        class_name,
        superclass_reference_name,
      )
      if table_name = @next_class_table_name
        model_declaration.set_source_table_name(table_name)
      end
      @next_class_table_name = nil
      @list_of_model_stack << model_declaration
      true
    end

    def end_visit(node : Crystal::ClassDef) : Nil
      model_declaration = @list_of_model_stack.pop?
      @list_of_model_declarations << model_declaration if model_declaration
    end

    def visit(node : Crystal::Def) : Bool
      @method_depth += 1
      true
    end

    def end_visit(node : Crystal::Def) : Nil
      @method_depth -= 1
    end

    def visit(node : Crystal::Macro) : Bool
      @macro_depth += 1
      true
    end

    def end_visit(node : Crystal::Macro) : Nil
      @macro_depth -= 1
    end

    def visit(node : Crystal::Annotation) : Bool
      if node.path.names == ["Grant", "Table"]
        annotation_name = node.named_args.try(&.find { |argument| argument.name == "name" })
        @next_class_table_name = SourceNode.literal_name(annotation_name.try(&.value))
      end
      true
    end

    def visit(node : Crystal::Call) : Bool
      if SourceNode.full_call_name(node) == "Grant::SchemaTenant.with"
        @uses_schema_tenancy = true
      end

      return true unless current_class_body?

      model_declaration = @list_of_model_stack.last
      case node.name
      when "multitenant"
        return true unless node.obj.nil?

        model_declaration.capture_multitenant_column(SourceNode.literal_name(node.args.first?))
        @uses_row_tenancy = true
      when "schema_tenant_excluded"
        return true unless node.obj.nil?

        model_declaration.mark_schema_tenant_excluded
        @uses_schema_tenancy = true
      when "column"
        return true unless node.obj.nil?

        column_declaration = column_declaration_from(node.args.first?)
        model_declaration.add_column_declaration(*column_declaration) if column_declaration
      when "table"
        return true unless node.obj.nil?

        table_name = SourceNode.literal_name(node.args.first?)
        model_declaration.set_source_table_name(table_name) if table_name
      end

      true
    end

    private def current_class_body? : Bool
      !@list_of_model_stack.empty? && @method_depth == 0 && @macro_depth == 0
    end

    private def column_declaration_from(node : Crystal::ASTNode?) : Tuple(String, Crystal::ASTNode)?
      case node
      when Crystal::TypeDeclaration
        variable = node.var
        return {variable.name, variable} if variable.is_a?(Crystal::Var)
      when Crystal::SymbolLiteral
        return {node.value, node}
      when Crystal::Var
        return {node.name, node}
      when Crystal::Path
        return {node.names.last, node} unless node.names.empty?
      end

      nil
    end

    private def restore_namespace_stack : Nil
      previous_size = @list_of_namespace_stack_sizes.pop?
      return unless previous_size

      @list_of_namespace_segments = @list_of_namespace_segments[0, previous_size]
    end
  end
end
