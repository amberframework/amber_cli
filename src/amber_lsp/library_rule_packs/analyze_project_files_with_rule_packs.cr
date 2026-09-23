module AmberLSP::LibraryRulePacks
  class AnalyzeProjectFilesWithRulePacks
    def initialize(
      @project_context : AmberLSP::ProjectContext,
      @configuration : AmberLSP::Configuration,
      @list_of_rule_packs : Array(DescribeLibraryRulePack),
    )
    end

    def has_applicable_pack?(file_path : String, content : String) : Bool
      @list_of_rule_packs.any? do |rule_pack|
        next true if library_is_project_root?(rule_pack)

        DetermineProjectRulePackState.new(@project_context, rule_pack, file_path, content)
          .has_any_applicable_mode?
      end
    end

    def list_of_diagnostics_for(file_path : String, content : String) : Array(Rules::Diagnostic)
      relative_file_path = project_relative_path(file_path)
      list_of_diagnostics = [] of Rules::Diagnostic

      @list_of_rule_packs.each do |rule_pack|
        next if library_is_project_root?(rule_pack)

        project_state = DetermineProjectRulePackState.new(
          @project_context,
          rule_pack,
          file_path,
          content,
        )

        rule_pack.list_of_rules.each do |rule|
          next unless @configuration.rule_enabled?(rule.rule_id)
          next unless rule_applies_to_file?(rule, relative_file_path)

          if rule.check.check_kind == "project_conflict"
            list_of_diagnostics.concat(
              project_conflict_diagnostics_for(rule_pack, rule, project_state)
            )
            next
          end

          next unless project_state.is_rule_mode_declared?(rule.list_of_mode_names)

          list_of_diagnostics.concat(
            file_diagnostics_for(rule_pack, rule, project_state, file_path, relative_file_path, content)
          )
        end
      end

      apply_configured_severity(list_of_diagnostics)
    end

    private def library_is_project_root?(rule_pack : DescribeLibraryRulePack) : Bool
      @project_context.shard_name == rule_pack.library_shard_name
    end

    private def rule_applies_to_file?(rule : DescribeLibraryRulePack::Rule, relative_file_path : String) : Bool
      applies = rule.list_of_applicable_globs.any? do |pattern|
        Rules::RuleRegistry.file_matches_pattern?(relative_file_path, pattern)
      end
      return false unless applies

      rule.list_of_excluded_globs.none? do |pattern|
        Rules::RuleRegistry.file_matches_pattern?(relative_file_path, pattern)
      end
    end

    private def project_conflict_diagnostics_for(
      rule_pack : DescribeLibraryRulePack,
      rule : DescribeLibraryRulePack::Rule,
      project_state : DetermineProjectRulePackState,
    ) : Array(Rules::Diagnostic)
      conflict_found = case rule.check.project_condition
                       when "mixed_modes"
                         project_state.all_modes_are_present?(rule.list_of_mode_names)
                       when "evidence_without_declaration"
                         project_state.has_undeclared_mode_evidence?(rule.list_of_mode_names)
                       else
                         false
                       end
      return [] of Rules::Diagnostic unless conflict_found

      [diagnostic_at_start_of_file(rule, severity_for(rule.severity_name))]
    end

    private def file_diagnostics_for(
      rule_pack : DescribeLibraryRulePack,
      rule : DescribeLibraryRulePack::Rule,
      project_state : DetermineProjectRulePackState,
      file_path : String,
      relative_file_path : String,
      content : String,
    ) : Array(Rules::Diagnostic)
      case rule.check.check_kind
      when "line_regex"
        line_regex_diagnostics_for(rule, relative_file_path, content)
      when "file_requires"
        file_requires_diagnostics_for(rule_pack, rule, content)
      when "call_outside_block"
        call_outside_block_diagnostics_for(rule, project_state, file_path, content)
      else
        [] of Rules::Diagnostic
      end
    end

    private def line_regex_diagnostics_for(
      rule : DescribeLibraryRulePack::Rule,
      relative_file_path : String,
      content : String,
    ) : Array(Rules::Diagnostic)
      custom_rule = Rules::CustomRule.new(
        id: rule.rule_id,
        description: rule.diagnostic_message,
        default_severity: severity_for(rule.severity_name),
        applies_to: rule.list_of_applicable_globs,
        pattern: Regex.new(rule.check.regex_pattern),
        message_template: rule.diagnostic_message,
        negate: rule.check.negates_pattern?,
      )
      custom_rule.check(relative_file_path, content)
    end

    private def file_requires_diagnostics_for(
      rule_pack : DescribeLibraryRulePack,
      rule : DescribeLibraryRulePack::Rule,
      content : String,
    ) : Array(Rules::Diagnostic)
      required_pattern = Regex.new(rule.check.required_regex_pattern)
      return [] of Rules::Diagnostic if content.each_line.any? { |line| required_pattern.matches?(line) }

      trigger_pattern = trigger_pattern_for(rule_pack, rule)
      return [] of Rules::Diagnostic unless trigger_pattern

      list_of_diagnostics = [] of Rules::Diagnostic
      content.each_line.with_index do |line, line_number|
        match = trigger_pattern.match(line)
        next unless match

        start_character = (match.begin(0) || 0).to_i32
        end_character = (match.end(0) || line.size).to_i32
        range = Rules::TextRange.new(
          Rules::Position.new(line_number.to_i32, start_character),
          Rules::Position.new(line_number.to_i32, end_character),
        )
        list_of_diagnostics << Rules::Diagnostic.new(
          range,
          severity_for(rule.severity_name),
          rule.rule_id,
          rule.diagnostic_message,
        )
      end

      list_of_diagnostics
    end

    private def trigger_pattern_for(
      rule_pack : DescribeLibraryRulePack,
      rule : DescribeLibraryRulePack::Rule,
    ) : Regex?
      unless rule.check.trigger_regex_pattern.empty?
        return Regex.new(rule.check.trigger_regex_pattern)
      end

      mode = rule_pack.modes_by_name[rule.list_of_mode_names.first]?
      tenant_column_name = mode.try(&.tenant_column_name)
      return nil unless tenant_column_name
      return nil unless tenant_column_name.matches?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)

      Regex.new("^\\s*column\\s+#{tenant_column_name}\\b")
    end

    private def call_outside_block_diagnostics_for(
      rule : DescribeLibraryRulePack::Rule,
      project_state : DetermineProjectRulePackState,
      file_path : String,
      content : String,
    ) : Array(Rules::Diagnostic)
      check = rule.check
      list_of_scoped_model_names = project_state.list_of_scoped_model_names_for(
        check.list_of_source_globs,
        check.model_macro_name,
      )
      return [] of Rules::Diagnostic if list_of_scoped_model_names.empty?

      visitor = VisitCrystalCallsOutsideRequiredBlocks.new(
        list_of_scoped_model_names,
        check.list_of_query_method_names,
        check.required_block_call_name,
        check.escape_block_call_name,
        check.model_macro_name,
      )
      ast = Crystal::Parser.new(content).parse
      visitor.accept(ast)

      visitor.list_of_calls_outside_required_blocks.compact_map do |call|
        location = call.name_location || call.location
        next unless location

        line = (location.line_number - 1).to_i32
        start_character = (location.column_number - 1).to_i32
        range = Rules::TextRange.new(
          Rules::Position.new(line, start_character),
          Rules::Position.new(line, start_character + call.name.size),
        )
        Rules::Diagnostic.new(
          range,
          severity_for(rule.severity_name),
          rule.rule_id,
          rule.diagnostic_message,
        )
      end
    rescue Crystal::SyntaxException
      [] of Rules::Diagnostic
    end

    private def diagnostic_at_start_of_file(
      rule : DescribeLibraryRulePack::Rule,
      severity : Rules::Severity,
    ) : Rules::Diagnostic
      range = Rules::TextRange.new(
        Rules::Position.new(0, 0),
        Rules::Position.new(0, 0),
      )
      Rules::Diagnostic.new(range, severity, rule.rule_id, rule.diagnostic_message)
    end

    private def apply_configured_severity(
      list_of_diagnostics : Array(Rules::Diagnostic),
    ) : Array(Rules::Diagnostic)
      list_of_diagnostics.map do |diagnostic|
        configured_severity = @configuration.rule_severity(diagnostic.code, diagnostic.severity)
        next diagnostic if configured_severity == diagnostic.severity

        Rules::Diagnostic.new(
          diagnostic.range,
          configured_severity,
          diagnostic.code,
          diagnostic.message,
          diagnostic.source,
        )
      end
    end

    private def severity_for(severity_name : String) : Rules::Severity
      case severity_name.downcase
      when "error" then Rules::Severity::Error
      when "info"  then Rules::Severity::Information
      when "hint"  then Rules::Severity::Hint
      else              Rules::Severity::Warning
      end
    end

    private def project_relative_path(file_path : String) : String
      project_root = File.expand_path(@project_context.root_path)
      absolute_file_path = File.expand_path(file_path)
      prefix = project_root.ends_with?(File::SEPARATOR) ? project_root : "#{project_root}#{File::SEPARATOR}"
      return file_path unless absolute_file_path.starts_with?(prefix)

      absolute_file_path[prefix.size..]
    end
  end
end
