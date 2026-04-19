module AmberLSP::Rules::Controllers
  class BeforeActionRule < AmberLSP::Rules::BaseRule
    def id : String
      "amber/filter-syntax"
    end

    def description : String
      "Detect Rails-style before_action :method_name and deprecated before_filter/after_filter syntax"
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

      rails_action_pattern = /^\s*(before_action|after_action)\s+:(\w+)/
      deprecated_filter_pattern = /^\s*(before_filter|after_filter)\b/

      content.each_line.with_index do |line, line_number|
        # Check for Rails-style symbol syntax: before_action :method_name
        rails_match = rails_action_pattern.match(line)
        if rails_match
          start_char = (rails_match.begin(0) || 0).to_i32
          end_char = (rails_match.end(0) || line.size).to_i32
          # Trim leading whitespace from the range start
          actual_start = (rails_match.begin(1) || start_char).to_i32

          diagnostics << Diagnostic.new(
            range: TextRange.new(
              Position.new(line_number.to_i32, actual_start),
              Position.new(line_number.to_i32, end_char)
            ),
            severity: default_severity,
            code: id,
            message: "Rails-style '#{rails_match[1]} :#{rails_match[2]}' is not supported in Amber. Use 'before_action do ... end' block syntax instead."
          )
          next
        end

        # Check for deprecated filter syntax
        filter_match = deprecated_filter_pattern.match(line)
        if filter_match
          start_char = (filter_match.begin(1) || 0).to_i32
          end_char = (filter_match.end(1) || line.size).to_i32

          diagnostics << Diagnostic.new(
            range: TextRange.new(
              Position.new(line_number.to_i32, start_char),
              Position.new(line_number.to_i32, end_char)
            ),
            severity: default_severity,
            code: id,
            message: "'#{filter_match[1]}' is deprecated. Use '#{filter_match[1].gsub("filter", "action")}' instead."
          )
        end
      end

      diagnostics
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::BeforeActionRule.new)
