module AmberLSP::Rules::Channels
  class HandleMessageRule < AmberLSP::Rules::BaseRule
    def id : String
      "amber/channel-handle-message"
    end

    def description : String
      "Non-abstract channel classes inheriting Amber::WebSockets::Channel must define handle_message"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Error
    end

    def applies_to : Array(String)
      ["src/channels/*"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      return [] of Diagnostic unless file_path.includes?("channels/")

      diagnostics = [] of Diagnostic
      class_pattern = /^\s*class\s+(\w+)\s*<\s*Amber::WebSockets::Channel/
      abstract_class_pattern = /^\s*abstract\s+class\s+\w+/
      handle_message_pattern = /^\s+def\s+handle_message\b/

      has_handle_message = content.lines.any? { |line| handle_message_pattern.matches?(line) }

      content.each_line.with_index do |line, line_number|
        # Skip abstract classes
        next if abstract_class_pattern.matches?(line)

        match = class_pattern.match(line)
        next unless match

        unless has_handle_message
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
            message: "Channel class '#{class_name}' must define a 'handle_message' method"
          )
        end
      end

      diagnostics
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Channels::HandleMessageRule.new)
