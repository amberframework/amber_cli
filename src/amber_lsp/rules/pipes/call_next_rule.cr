module AmberLSP::Rules::Pipes
  class CallNextRule < AmberLSP::Rules::BaseRule
    def id : String
      "amber/pipe-call-next"
    end

    def description : String
      "Pipe classes that override call must invoke call_next to continue the pipeline"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Error
    end

    def applies_to : Array(String)
      ["*.cr"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      diagnostics = [] of Diagnostic

      # Check if this file defines a class inheriting from Amber::Pipe::Base
      pipe_class_pattern = /^\s*class\s+(\w+)\s*<\s*Amber::Pipe::Base/
      return diagnostics unless content.lines.any? { |line| pipe_class_pattern.matches?(line) }

      # Now scan for call method definitions and check for call_next
      lines = content.lines
      in_call_method = false
      call_method_line = 0
      call_method_start_char = 0
      call_method_end_char = 0
      call_method_indent = 0
      has_call_next = false

      lines.each_with_index do |line, line_number|
        call_match = /^(\s+)def\s+call\b/.match(line)
        if call_match && !in_call_method
          in_call_method = true
          call_method_line = line_number
          call_method_indent = call_match[1].size
          # Find the "call" method name position
          name_match = /\bdef\s+(call)\b/.match(line)
          if name_match
            call_method_start_char = (name_match.begin(1) || 0).to_i32
            call_method_end_char = (name_match.end(1) || line.size).to_i32
          end
          has_call_next = false
          next
        end

        if in_call_method
          if line.includes?("call_next")
            has_call_next = true
          end

          end_match = /^(\s*)end\b/.match(line)
          if end_match
            end_indent = end_match[1].size
            if end_indent <= call_method_indent
              unless has_call_next
                diagnostics << Diagnostic.new(
                  range: TextRange.new(
                    Position.new(call_method_line.to_i32, call_method_start_char),
                    Position.new(call_method_line.to_i32, call_method_end_char)
                  ),
                  severity: default_severity,
                  code: id,
                  message: "Pipe's 'call' method must invoke 'call_next' to continue the middleware pipeline"
                )
              end
              in_call_method = false
            end
          end
        end
      end

      diagnostics
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Pipes::CallNextRule.new)
