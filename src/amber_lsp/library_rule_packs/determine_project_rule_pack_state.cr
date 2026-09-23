require "set"

module AmberLSP::LibraryRulePacks
  class DetermineProjectRulePackState
    @is_mode_declared_by_name = {} of String => Bool
    @has_mode_evidence_by_name = {} of String => Bool
    @project_source_content_by_path = {} of String => String

    def initialize(
      @project_context : AmberLSP::ProjectContext,
      @rule_pack : DescribeLibraryRulePack,
      @file_path : String,
      @file_content : String,
    )
      load_project_source_content
      determine_mode_declarations
      determine_mode_evidence
    end

    def is_mode_declared?(mode_name : String) : Bool
      @is_mode_declared_by_name[mode_name]? || false
    end

    def has_evidence_for_mode?(mode_name : String) : Bool
      @has_mode_evidence_by_name[mode_name]? || false
    end

    def is_mode_present?(mode_name : String) : Bool
      is_mode_declared?(mode_name) || has_evidence_for_mode?(mode_name)
    end

    def has_any_applicable_mode? : Bool
      @rule_pack.modes_by_name.keys.any? do |mode_name|
        is_mode_declared?(mode_name) || has_evidence_for_mode?(mode_name)
      end
    end

    def all_modes_are_present?(list_of_mode_names : Array(String)) : Bool
      !list_of_mode_names.empty? && list_of_mode_names.all? { |mode_name| is_mode_present?(mode_name) }
    end

    def has_undeclared_mode_evidence?(list_of_mode_names : Array(String)) : Bool
      list_of_mode_names.any? do |mode_name|
        has_evidence_for_mode?(mode_name) && !is_mode_declared?(mode_name)
      end
    end

    def is_rule_mode_declared?(list_of_mode_names : Array(String)) : Bool
      list_of_mode_names.any? { |mode_name| is_mode_declared?(mode_name) }
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
      project_root = File.expand_path(@project_context.root_path)

      Dir.glob(File.join(project_root, "**", "*.cr")).each do |file_path|
        next unless project_file_is_application_source?(file_path, project_root)

        content = if File.expand_path(file_path) == File.expand_path(@file_path)
                    @file_content
                  else
                    File.read(file_path)
                  end
        @project_source_content_by_path[File.expand_path(file_path)] = content
      rescue
        next
      end

      current_file_path = File.expand_path(@file_path)
      if project_file_is_application_source?(current_file_path, project_root)
        @project_source_content_by_path[current_file_path] = @file_content
      end
    end

    private def project_file_is_application_source?(file_path : String, project_root : String) : Bool
      prefix = project_root.ends_with?(File::SEPARATOR) ? project_root : "#{project_root}#{File::SEPARATOR}"
      return false unless file_path.starts_with?(prefix)

      relative_path = file_path[prefix.size..]
      return false if relative_path.starts_with?("lib/")
      return false if relative_path.starts_with?(".git/")
      return false if relative_path.starts_with?("tmp/")
      return false if relative_path.starts_with?("vendor/")

      true
    end

    private def determine_mode_declarations : Nil
      @rule_pack.modes_by_name.each do |mode_name, mode|
        @is_mode_declared_by_name[mode_name] = @project_context.has_shard_declaration?(
          mode.declaration.key_path,
          mode.declaration.expected_value,
        )
      end
    end

    private def determine_mode_evidence : Nil
      @rule_pack.modes_by_name.each do |mode_name, mode|
        evidence_found = mode.list_of_evidence_patterns.any? do |pattern|
          regex = Regex.new(pattern)
          @project_source_content_by_path.values.any? do |content|
            content.each_line.any? { |line| regex.matches?(line) }
          end
        end
        @has_mode_evidence_by_name[mode_name] = evidence_found
      end
    rescue ArgumentError
      @rule_pack.modes_by_name.each_key { |mode_name| @has_mode_evidence_by_name[mode_name] = false }
    end

    private def project_relative_path(file_path : String) : String
      project_root = File.expand_path(@project_context.root_path)
      prefix = project_root.ends_with?(File::SEPARATOR) ? project_root : "#{project_root}#{File::SEPARATOR}"
      return file_path unless file_path.starts_with?(prefix)

      file_path[prefix.size..]
    end
  end
end
