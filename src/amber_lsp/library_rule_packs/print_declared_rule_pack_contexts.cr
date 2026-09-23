module AmberLSP::LibraryRulePacks
  class PrintDeclaredRulePackContexts
    def initialize(@list_of_arguments : Array(String))
    end

    def perform : Int32
      project_context = AmberLSP::ProjectContext.detect(project_root_from_arguments)
      list_of_rule_packs = LoadRulePacksForProject.new(project_context).load_rule_packs
      list_of_output_lines = [] of String

      list_of_rule_packs.each do |rule_pack|
        next if project_context.shard_name == rule_pack.library_shard_name

        project_state = DetermineProjectRulePackState.new(project_context, rule_pack, "", "")
        next unless project_state.has_any_applicable_mode?

        append_declared_mode_contexts(list_of_output_lines, rule_pack, project_state)
        append_undeclared_feature_warning(list_of_output_lines, rule_pack, project_state)
      end

      STDOUT.puts(list_of_output_lines.join('\n')) unless list_of_output_lines.empty?
      0
    rescue ex
      STDERR.puts "amber-lsp context failed: #{ex.message}"
      1
    end

    private def project_root_from_arguments : String
      project_root = Dir.current
      arguments = @list_of_arguments.dup

      until arguments.empty?
        argument = arguments.shift
        case argument
        when "--root"
          root_argument = arguments.shift?
          raise ArgumentError.new("--root requires a directory") unless root_argument
          project_root = File.expand_path(root_argument)
        else
          raise ArgumentError.new("unexpected argument #{argument.inspect}")
        end
      end

      find_project_root(project_root)
    end

    private def find_project_root(start_path : String) : String
      current_path = File.expand_path(start_path)
      current_path = File.dirname(current_path) unless File.directory?(current_path)

      loop do
        return current_path if File.file?(File.join(current_path, "shard.yml"))

        parent_path = File.dirname(current_path)
        return current_path if parent_path == current_path
        current_path = parent_path
      end
    end

    private def append_declared_mode_contexts(
      list_of_output_lines : Array(String),
      rule_pack : DescribeLibraryRulePack,
      project_state : DetermineProjectRulePackState,
    ) : Nil
      rule_pack.modes_by_name.each do |mode_name, mode|
        next unless project_state.is_mode_declared?(mode_name)
        next if mode.guidance_text.strip.empty?

        list_of_output_lines << "#{rule_pack.pack_id} (#{mode_name})"
        list_of_output_lines.concat(mode.guidance_text.lines.map(&.rstrip))
      end
    end

    private def append_undeclared_feature_warning(
      list_of_output_lines : Array(String),
      rule_pack : DescribeLibraryRulePack,
      project_state : DetermineProjectRulePackState,
    ) : Nil
      list_of_undeclared_mode_names = rule_pack.modes_by_name.keys.select do |mode_name|
        project_state.has_evidence_for_mode?(mode_name) && !project_state.is_mode_declared?(mode_name)
      end
      return if list_of_undeclared_mode_names.empty?

      list_of_key_paths = list_of_undeclared_mode_names.compact_map do |mode_name|
        rule_pack.modes_by_name[mode_name]?.try(&.declaration.key_path)
      end
      list_of_output_lines << "warning: #{rule_pack.pack_id} feature is used but shard.yml does not declare #{list_of_key_paths.join(", ")}."
    end
  end
end
