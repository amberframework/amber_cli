module AmberLSP
  class Analyzer
    getter configuration : Configuration

    def initialize
      @configuration = Configuration.new
    end

    def configure(project_context : ProjectContext) : Nil
      @configuration = Configuration.load(project_context.root_path)
      register_custom_rules
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
      return [] of Rules::Diagnostic if @configuration.excluded?(file_path)

      diagnostics = [] of Rules::Diagnostic
      rules = Rules::RuleRegistry.rules_for_file(file_path)

      rules.each do |rule|
        next unless @configuration.rule_enabled?(rule.id)

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

      diagnostics
    end
  end
end
