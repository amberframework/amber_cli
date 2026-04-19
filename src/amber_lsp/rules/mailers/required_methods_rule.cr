module AmberLSP::Rules::Mailers
  class RequiredMethodsRule < AmberLSP::Rules::BaseRule
    def id : String
      "amber/mailer-methods"
    end

    def description : String
      "Mailer classes inheriting Amber::Mailer::Base must define html_body and text_body"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Error
    end

    def applies_to : Array(String)
      ["src/mailers/*"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      return [] of Diagnostic unless file_path.includes?("mailers/")

      diagnostics = [] of Diagnostic
      class_pattern = /^\s*class\s+(\w+)\s*<\s*Amber::Mailer::Base/
      html_body_pattern = /^\s+def\s+html_body\b/
      text_body_pattern = /^\s+def\s+text_body\b/

      has_html_body = content.lines.any? { |line| html_body_pattern.matches?(line) }
      has_text_body = content.lines.any? { |line| text_body_pattern.matches?(line) }

      content.each_line.with_index do |line, line_number|
        match = class_pattern.match(line)
        next unless match

        class_name = match[1]
        start_char = (match.begin(1) || 0).to_i32
        end_char = (match.end(1) || line.size).to_i32

        unless has_html_body
          diagnostics << Diagnostic.new(
            range: TextRange.new(
              Position.new(line_number.to_i32, start_char),
              Position.new(line_number.to_i32, end_char)
            ),
            severity: default_severity,
            code: id,
            message: "Mailer class '#{class_name}' must define an 'html_body' method"
          )
        end

        unless has_text_body
          diagnostics << Diagnostic.new(
            range: TextRange.new(
              Position.new(line_number.to_i32, start_char),
              Position.new(line_number.to_i32, end_char)
            ),
            severity: default_severity,
            code: id,
            message: "Mailer class '#{class_name}' must define a 'text_body' method"
          )
        end
      end

      diagnostics
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Mailers::RequiredMethodsRule.new)
