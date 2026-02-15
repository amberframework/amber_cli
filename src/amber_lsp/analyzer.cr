module AmberLSP
  class Analyzer
    getter configuration : Configuration

    def initialize
      @configuration = Configuration.new
    end

    def configure(project_context : ProjectContext) : Nil
      @configuration = Configuration.load(project_context.root_path)
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
