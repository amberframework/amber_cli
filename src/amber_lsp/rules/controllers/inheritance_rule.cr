module AmberLSP::Rules::Controllers
  class InheritanceRule < AmberLSP::Rules::BaseRule
    VALID_BASE_CLASSES = ["ApplicationController", "Amber::Controller::Base"]

    def id : String
      "amber/controller-inheritance"
    end

    def description : String
      "Controller classes must inherit from ApplicationController or Amber::Controller::Base"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Error
    end

    def applies_to : Array(String)
      ["src/controllers/*"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      return [] of Diagnostic unless file_path.includes?("controllers/")
      return [] of Diagnostic if file_path.ends_with?("application_controller.cr")

      diagnostics = [] of Diagnostic
      class_pattern = /^\s*class\s+\w+Controller\s*<\s*(\S+)/

      content.each_line.with_index do |line, line_number|
        match = class_pattern.match(line)
        next unless match

        parent_class = match[1]
        unless VALID_BASE_CLASSES.includes?(parent_class)
          start_char = (match.begin(1) || 0).to_i32
          end_char = (match.end(1) || line.size).to_i32

          diagnostics << Diagnostic.new(
            range: TextRange.new(
              Position.new(line_number.to_i32, start_char),
              Position.new(line_number.to_i32, end_char)
            ),
            severity: default_severity,
            code: id,
            message: "Controller should inherit from ApplicationController or Amber::Controller::Base, found '#{parent_class}'"
          )
        end
      end

      diagnostics
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::InheritanceRule.new)
