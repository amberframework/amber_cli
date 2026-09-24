module AmberLSP
  class Analyzer
    getter configuration : Configuration
    @project_root : String?
    @project_context : ProjectContext?
    @library_rule_pack_analyzer : LibraryRulePacks::AnalyzeProjectFilesWithRulePacks?

    def initialize
      @configuration = Configuration.new
      @project_root = nil
      @project_context = nil
      @library_rule_pack_analyzer = nil
    end

    def configure(project_context : ProjectContext) : Nil
      @configuration = Configuration.load(project_context.root_path)
      @project_root = project_context.root_path
      @project_context = project_context
      list_of_rule_packs = LibraryRulePacks::LoadRulePacksForProject.new(project_context).load_rule_packs
      @library_rule_pack_analyzer = LibraryRulePacks::AnalyzeProjectFilesWithRulePacks.new(
        project_context,
        @configuration,
        list_of_rule_packs,
      )
      register_custom_rules
    end

    def has_applicable_library_rule_pack?(file_path : String, content : String) : Bool
      analyzer = @library_rule_pack_analyzer
      return false unless analyzer

      analyzer.has_applicable_pack?(file_path, content)
    end

    private def register_custom_rules : Nil
      @configuration.custom_rules.each do |custom_config|
        severity = case custom_config.severity
                   when "error"   then Rules::Severity::Error
                   when "warning" then Rules::Severity::Warning
                   when "info"    then Rules::Severity::Information
                   when "hint"    then Rules::Severity::Hint
                   else                Rules::Severity::Warning
                   end

        rule = Rules::CustomRule.new(
          id: custom_config.id,
          description: custom_config.description,
          default_severity: severity,
          applies_to: custom_config.applies_to,
          pattern: Regex.new(custom_config.pattern),
          message_template: custom_config.message,
          negate: custom_config.negate?,
        )
        Rules::RuleRegistry.register(rule)
      end
    rescue ex
      STDERR.puts "WARNING: Failed to load custom rules: #{ex.message}"
    end

    def analyze(file_path : String, content : String) : Array(Rules::Diagnostic)
      relative_file_path = project_relative_path(file_path)
      return [] of Rules::Diagnostic if @configuration.excluded?(relative_file_path)

      diagnostics = [] of Rules::Diagnostic
      rules = Rules::RuleRegistry.rules_for_file(relative_file_path)

      rules.each do |rule|
        next unless @configuration.rule_enabled?(rule.id)
        if rule.requires_amber_project?
          project_context = @project_context
          next unless project_context && project_context.amber_project?
        end

        rule_diagnostics = rule.check(file_path, content)
        severity = @configuration.rule_severity(rule.id, rule.default_severity)

        rule_diagnostics.each do |diagnostic|
          if diagnostic.severity != severity
            diagnostics << Rules::Diagnostic.new(
              range: diagnostic.range,
              severity: severity,
              code: diagnostic.code,
              message: diagnostic.message,
              source: diagnostic.source
            )
          else
            diagnostics << diagnostic
          end
        end
      end

      if analyzer = @library_rule_pack_analyzer
        diagnostics.concat(analyzer.list_of_diagnostics_for(file_path, content))
      end

      diagnostics
    end

    private def project_relative_path(file_path : String) : String
      project_root = @project_root
      return file_path unless project_root

      separator = File::SEPARATOR.to_s
      root_prefix = project_root.ends_with?(separator) ? project_root : "#{project_root}#{separator}"

      return file_path unless file_path.starts_with?(root_prefix)

      file_path[root_prefix.size..]
    end
  end
end
