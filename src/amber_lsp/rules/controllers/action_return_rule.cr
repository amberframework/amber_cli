module AmberLSP::Rules::Controllers
  class ActionReturnRule < AmberLSP::Rules::BaseRule
    RESPONSE_METHODS  = ["render", "redirect_to", "redirect_back", "respond_with", "halt!"]
    SKIPPED_METHODS   = ["initialize", "before_action", "after_action", "before_filter", "after_filter"]
    VISIBILITY_CHANGE = /^\s*(private|protected)\s*$/

    def id : String
      "amber/action-return-type"
    end

    def description : String
      "Public controller actions should call render, redirect_to, redirect_back, respond_with, or halt!"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Warning
    end

    def applies_to : Array(String)
      ["src/controllers/*"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      return [] of Diagnostic unless file_path.includes?("controllers/")

      diagnostics = [] of Diagnostic
      lines = content.lines

      in_public_method = false
      method_name = ""
      method_line = 0
      method_start_char = 0
      method_end_char = 0
      method_indent = 0
      has_response_call = false
      is_private_section = false

      lines.each_with_index do |line, line_number|
        # Track visibility section changes
        if VISIBILITY_CHANGE.matches?(line)
          is_private_section = true
          next
        end

        # Detect method start at standard 2-space indent (methods inside a class)
        method_match = /^(\s{2,4})def\s+(\w+)/.match(line)
        if method_match && !in_public_method
          indent = method_match[1].size
          name = method_match[2]

          # Skip private/protected methods and special methods
          next if is_private_section
          next if SKIPPED_METHODS.includes?(name)
          next if line.includes?("private def") || line.includes?("protected def")

          in_public_method = true
          method_name = name
          method_line = line_number
          method_start_char = (method_match.begin(2) || 0).to_i32
          method_end_char = (method_match.end(2) || line.size).to_i32
          method_indent = indent
          has_response_call = false
          next
        end

        if in_public_method
          # Check for response method calls
          if RESPONSE_METHODS.any? { |m| line.includes?(m) }
            has_response_call = true
          end

          # Detect method end at same or lesser indent level
          end_match = /^(\s*)end\b/.match(line)
          if end_match
            end_indent = end_match[1].size
            if end_indent <= method_indent
              unless has_response_call
                diagnostics << Diagnostic.new(
                  range: TextRange.new(
                    Position.new(method_line.to_i32, method_start_char),
                    Position.new(method_line.to_i32, method_end_char)
                  ),
                  severity: default_severity,
                  code: id,
                  message: "Action '#{method_name}' does not appear to call render, redirect_to, redirect_back, respond_with, or halt!"
                )
              end
              in_public_method = false
            end
          end
        end
      end

      diagnostics
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Controllers::ActionReturnRule.new)
