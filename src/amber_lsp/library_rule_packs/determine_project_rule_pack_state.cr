require "set"

module AmberLSP::LibraryRulePacks
  class DetermineProjectRulePackState
    @uses_row_tenancy = false
    @uses_schema_tenancy = false
    @project_source_content_by_path = {} of String => String
    @list_of_model_declarations_by_file = {} of String => Array(GrantTenancy::GrantTenantModelDeclaration)
    @list_of_model_declarations = [] of GrantTenancy::GrantTenantModelDeclaration
    @list_of_row_tenant_column_names = Set(String).new

    def initialize(
      @project_context : AmberLSP::ProjectContext,
      @rule_pack : DescribeLibraryRulePack,
      @file_path : String,
      @file_content : String,
    )
      load_project_source_content
    end

    def mode_detected?(mode_name : String) : Bool
      case mode_name
      when "row"
        @uses_row_tenancy
      when "schema"
        @uses_schema_tenancy
      else
        false
      end
    end

    def has_any_applicable_mode? : Bool
      @rule_pack.modes_by_name.keys.any? { |mode_name| mode_detected?(mode_name) }
    end

    def all_modes_are_present?(list_of_mode_names : Array(String)) : Bool
      !list_of_mode_names.empty? && list_of_mode_names.all? { |mode_name| mode_detected?(mode_name) }
    end

    def rule_mode_detected?(list_of_mode_names : Array(String)) : Bool
      list_of_mode_names.any? { |mode_name| mode_detected?(mode_name) }
    end

    def has_row_tenant_model?(model_reference_name : String) : Bool
      matching_model_declarations(model_reference_name).any?(&.has_multitenant_macro?)
    end

    def has_schema_excluded_model?(model_reference_name : String) : Bool
      matching_model_declarations(model_reference_name).any?(&.schema_tenant_excluded?)
    end

    def has_non_excluded_schema_model?(model_reference_name : String) : Bool
      matching_model_declarations(model_reference_name).any? do |model_declaration|
        model_declaration_is_grant_model?(model_declaration) &&
          !has_schema_excluded_model?(model_declaration.qualified_model_name)
      end
    end

    def list_of_row_tenant_table_names : Array(String)
      @list_of_model_declarations.compact_map do |model_declaration|
        next unless model_declaration.has_multitenant_macro?

        model_declaration.source_table_name
      end.uniq
    end

    def list_of_tenant_column_declarations_for(file_path : String) : Array(Tuple(String, Crystal::ASTNode))
      absolute_file_path = File.expand_path(file_path)
      list_of_current_file_models = @list_of_model_declarations_by_file[absolute_file_path]?
      return [] of Tuple(String, Crystal::ASTNode) unless list_of_current_file_models
      return [] of Tuple(String, Crystal::ASTNode) if @list_of_row_tenant_column_names.empty?

      list_of_findings = [] of Tuple(String, Crystal::ASTNode)

      list_of_current_file_models.each do |model_declaration|
        next unless model_declaration_is_grant_model?(model_declaration)
        next if has_row_tenant_model?(model_declaration.qualified_model_name)

        model_declaration.list_of_column_declarations.each do |column_declaration|
          tenant_column_name = column_declaration[0]
          next unless @list_of_row_tenant_column_names.includes?(tenant_column_name)
          next if model_table_is_referenced_by_column?(model_declaration, tenant_column_name)

          list_of_findings << column_declaration
        end
      end

      list_of_findings
    end

    def list_of_scoped_model_names_for(
      source_globs : Array(String),
      model_macro_name : String,
    ) : Set(String)
      list_of_model_names = Set(String).new

      @project_source_content_by_path.each do |file_path, content|
        relative_path = project_relative_path(file_path)
        next unless source_globs.any? { |pattern| Rules::RuleRegistry.file_matches_pattern?(relative_path, pattern) }

        list_of_model_names.concat(
          VisitCrystalCallsOutsideRequiredBlocks.find_multitenant_model_names(content, model_macro_name)
        )
      end

      list_of_model_names
    end

    private def load_project_source_content : Nil
      project_source_file_paths.each do |file_path|
        content = content_for(file_path)
        next unless content

        absolute_file_path = File.expand_path(file_path)
        @project_source_content_by_path[absolute_file_path] = content
        collect_project_declarations_from(absolute_file_path, content)
      end

      current_file_path = File.expand_path(@file_path)
      if project_file_is_application_source?(current_file_path) &&
         !@project_source_content_by_path.has_key?(current_file_path)
        @project_source_content_by_path[current_file_path] = @file_content
        collect_project_declarations_from(current_file_path, @file_content)
      end
    end

    private def project_source_file_paths : Array(String)
      project_root = File.expand_path(@project_context.root_path)
      list_of_source_file_paths = Dir.glob(File.join(project_root, "src", "**", "*.cr"))
      list_of_source_file_paths.concat(Dir.glob(File.join(project_root, "config", "**", "*.cr")))
      list_of_source_file_paths.uniq.sort
    end

    private def content_for(file_path : String) : String?
      if File.expand_path(file_path) == File.expand_path(@file_path)
        return @file_content
      end

      File.read(file_path)
    rescue IO::Error
      nil
    end

    private def collect_project_declarations_from(file_path : String, content : String) : Nil
      collector = GrantTenancy::CollectProjectGrantTenancyDeclarations.for_source(content)
      @uses_row_tenancy ||= collector.uses_row_tenancy?
      @uses_schema_tenancy ||= collector.uses_schema_tenancy?
      @list_of_model_declarations_by_file[file_path] = collector.list_of_model_declarations
      @list_of_model_declarations.concat(collector.list_of_model_declarations)

      collector.list_of_model_declarations.each do |model_declaration|
        tenant_column_name = model_declaration.tenant_column_name
        next unless model_declaration.has_multitenant_macro? && tenant_column_name

        @list_of_row_tenant_column_names.add(tenant_column_name)
      end
    end

    private def project_file_is_application_source?(file_path : String) : Bool
      project_root = File.expand_path(@project_context.root_path)
      prefix = project_root.ends_with?(File::SEPARATOR) ? project_root : "#{project_root}#{File::SEPARATOR}"
      return false unless file_path.starts_with?(prefix)

      relative_path = file_path[prefix.size..]
      (relative_path.starts_with?("src/") || relative_path.starts_with?("config/")) &&
        file_path.ends_with?(".cr")
    end

    private def matching_model_declarations(model_reference_name : String) : Array(GrantTenancy::GrantTenantModelDeclaration)
      list_of_exact_matches = @list_of_model_declarations.select do |model_declaration|
        model_declaration.qualified_model_name == model_reference_name
      end
      return list_of_exact_matches unless list_of_exact_matches.empty?
      return [] of GrantTenancy::GrantTenantModelDeclaration if model_reference_name.includes?("::")

      list_of_simple_name_matches = @list_of_model_declarations.select do |model_declaration|
        model_declaration.class_name == model_reference_name
      end
      unique_qualified_names = list_of_simple_name_matches.map(&.qualified_model_name).uniq
      return [] of GrantTenancy::GrantTenantModelDeclaration unless unique_qualified_names.size == 1

      list_of_simple_name_matches
    end

    private def model_declaration_is_grant_model?(
      model_declaration : GrantTenancy::GrantTenantModelDeclaration,
      list_of_visited_model_names : Set(String) = Set(String).new,
    ) : Bool
      return true if model_declaration.grant_model?
      return false if list_of_visited_model_names.includes?(model_declaration.qualified_model_name)

      list_of_visited_model_names.add(model_declaration.qualified_model_name)
      superclass_reference_name = model_declaration.superclass_reference_name
      return false unless superclass_reference_name
      return true if superclass_reference_name == "Grant::Base"

      matching_model_declarations(superclass_reference_name).any? do |parent_model_declaration|
        model_declaration_is_grant_model?(parent_model_declaration, list_of_visited_model_names)
      end
    end

    private def model_table_is_referenced_by_column?(
      model_declaration : GrantTenancy::GrantTenantModelDeclaration,
      tenant_column_name : String,
    ) : Bool
      return false unless tenant_column_name.ends_with?("_id")

      referenced_table_base_name = tenant_column_name[0, tenant_column_name.size - 3]
      list_of_referenced_table_names = [referenced_table_base_name, "#{referenced_table_base_name}s"]
      normalized_table_name = model_declaration.source_table_name.split('.').last
      return false unless normalized_table_name

      list_of_referenced_table_names.includes?(normalized_table_name.downcase)
    end

    private def project_relative_path(file_path : String) : String
      project_root = File.expand_path(@project_context.root_path)
      prefix = project_root.ends_with?(File::SEPARATOR) ? project_root : "#{project_root}#{File::SEPARATOR}"
      return file_path unless file_path.starts_with?(prefix)

      file_path[prefix.size..]
    end
  end
end
