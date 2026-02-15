module AmberLSP::Rules::Jobs
  class PerformRule < AmberLSP::Rules::BaseRule
    def id : String
      "amber/job-perform"
    end

    def description : String
      "Classes inheriting Amber::Jobs::Job must define a perform method"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Error
    end

    def applies_to : Array(String)
      ["src/jobs/*"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      return [] of Diagnostic unless file_path.includes?("jobs/")

      diagnostics = [] of Diagnostic
      class_pattern = /^\s*class\s+(\w+)\s*<\s*Amber::Jobs::Job/
      perform_pattern = /^\s+def\s+perform\b/

      has_perform = content.lines.any? { |line| perform_pattern.matches?(line) }

      content.each_line.with_index do |line, line_number|
        match = class_pattern.match(line)
        next unless match

        unless has_perform
          class_name = match[1]
          start_char = (match.begin(1) || 0).to_i32
          end_char = (match.end(1) || line.size).to_i32

          diagnostics << Diagnostic.new(
            range: TextRange.new(
              Position.new(line_number.to_i32, start_char),
              Position.new(line_number.to_i32, end_char)
            ),
            severity: default_severity,
            code: id,
            message: "Job class '#{class_name}' must define a 'perform' method"
          )
        end
      end

      diagnostics
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Jobs::PerformRule.new)
