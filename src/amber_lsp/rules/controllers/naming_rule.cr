module AmberLSP::Rules::Controllers
  class NamingRule < AmberLSP::Rules::BaseRule
    def id : String
      "amber/controller-naming"
    end

    def description : String
      "Classes defined in controllers/ must have names ending in 'Controller'"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Error
    end

    def applies_to : Array(String)
      ["src/controllers/*"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      return [] of Diagnostic unless file_path.includes?("controllers/")

      diagnostics = [] of Diagnostic
      class_pattern = /^\s*class\s+(\w+)\s*</

      content.each_line.with_index do |line, line_number|
        match = class_pattern.match(line)
        next unless match

        class_name = match[1]
        unless class_name.ends_with?("Controller")
          start_char = (match.begin(1) || 0).to_i32
          end_char = (match.end(1) || line.size).to_i32

          diagnostics << Diagnostic.new(
            range: TextRange.new(
              Position.new(line_number.to_i32, start_char),
              Position.new(line_number.to_i32, end_char)
            ),
            severity: default_severity,
            code: id,
            message: "Class '#{class_name}' in controllers/ directory should end with 'Controller'"
          )
        end
      end

      diagnostics
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::NamingRule.new)
