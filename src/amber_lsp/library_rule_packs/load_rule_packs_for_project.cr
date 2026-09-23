module AmberLSP::LibraryRulePacks
  class LoadRulePacksForProject
    def initialize(@project_context : AmberLSP::ProjectContext)
    end

    def load_rule_packs : Array(DescribeLibraryRulePack)
      list_of_packs_by_id = {} of String => DescribeLibraryRulePack

      dependency_pack_paths.each do |pack_path|
        load_rule_pack(pack_path).try do |rule_pack|
          list_of_packs_by_id[rule_pack.pack_id] = rule_pack
        end
      end

      project_pack_paths.each do |pack_path|
        load_rule_pack(pack_path).try do |rule_pack|
          list_of_packs_by_id[rule_pack.pack_id] = rule_pack
        end
      end

      list_of_packs_by_id.values.sort_by(&.pack_id)
    end

    private def dependency_pack_paths : Array(String)
      list_of_library_paths = Dir.glob(File.join(@project_context.root_path, "lib", "*")).sort
      list_of_library_paths.flat_map do |library_path|
        Dir.glob(File.join(library_path, ".claude", "rules", "*.yml"))
      end.sort
    end

    private def project_pack_paths : Array(String)
      Dir.glob(File.join(@project_context.root_path, ".claude", "rules", "*.yml")).sort
    end

    private def load_rule_pack(pack_path : String) : DescribeLibraryRulePack?
      rule_pack = DescribeLibraryRulePack.from_yaml(File.read(pack_path))
      return rule_pack if rule_pack_is_valid?(rule_pack)

      STDERR.puts "WARNING: Ignoring invalid amber-lsp rule pack at #{pack_path}."
      nil
    rescue ex
      STDERR.puts "WARNING: Could not load amber-lsp rule pack at #{pack_path}: #{ex.message}"
      nil
    end

    private def rule_pack_is_valid?(rule_pack : DescribeLibraryRulePack) : Bool
      return false unless rule_pack.is_valid?

      rule_pack.modes_by_name.each_value do |mode|
        mode.list_of_evidence_patterns.each { |pattern| Regex.new(pattern) }
      end

      rule_pack.list_of_rules.all? do |rule|
        next false unless {"error", "warning", "info", "hint"}.includes?(rule.severity_name.downcase)

        case rule.check.check_kind
        when "line_regex"
          Regex.new(rule.check.regex_pattern)
          true
        when "file_requires"
          !rule.check.required_regex_pattern.empty? &&
            (rule.check.trigger_regex_pattern.empty? || begin
              Regex.new(rule.check.trigger_regex_pattern)
              true
            end) && begin
            Regex.new(rule.check.required_regex_pattern)
            true
          end
        when "call_outside_block"
          !rule.check.list_of_source_globs.empty? &&
            !rule.check.list_of_query_method_names.empty? &&
            (!rule.check.required_block_call_name.empty? || !rule.check.escape_block_call_name.empty?)
        when "project_conflict"
          case rule.check.project_condition
          when "mixed_modes"
            rule.list_of_mode_names.size > 1
          when "evidence_without_declaration"
            rule.list_of_mode_names.size == 1
          else
            false
          end
        else
          false
        end
      end
    rescue ArgumentError
      false
    end
  end
end
