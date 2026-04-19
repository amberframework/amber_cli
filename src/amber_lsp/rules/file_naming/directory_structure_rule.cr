module AmberLSP::Rules::FileNaming
  class DirectoryStructureRule < AmberLSP::Rules::BaseRule
    LOCATION_RULES = [
      {pattern: /^\s*class\s+\w+Controller\s*</, directory: "src/controllers/"},
      {pattern: /^\s*class\s+\w+\s*<\s*Amber::Jobs::Job/, directory: "src/jobs/"},
      {pattern: /^\s*class\s+\w+\s*<\s*Amber::Mailer::Base/, directory: "src/mailers/"},
      {pattern: /^\s*class\s+\w+\s*<\s*Amber::WebSockets::Channel/, directory: "src/channels/"},
      {pattern: /^\s*class\s+\w+Schema\s*<\s*Amber::Schema::Definition/, directory: "src/schemas/"},
      {pattern: /^\s*struct\s+\w+\s*<\s*Amber::WebSockets::ClientSocket/, directory: "src/sockets/"},
    ]

    def id : String
      "amber/directory-structure"
    end

    def description : String
      "Files defining certain class types should be in the expected directory"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Warning
    end

    def applies_to : Array(String)
      ["*.cr"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      diagnostics = [] of Diagnostic

      content.each_line.with_index do |line, line_number|
        LOCATION_RULES.each do |rule|
          match = rule[:pattern].match(line)
          next unless match

          expected_dir = rule[:directory]
          unless file_path.includes?(expected_dir)
            start_char = (match.begin(0) || 0).to_i32
            end_char = (match.end(0) || line.size).to_i32

            diagnostics << Diagnostic.new(
              range: TextRange.new(
                Position.new(line_number.to_i32, start_char),
                Position.new(line_number.to_i32, end_char)
              ),
              severity: default_severity,
              code: id,
              message: "This class definition should be in the '#{expected_dir}' directory"
            )
          end
        end
      end

      diagnostics
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::FileNaming::DirectoryStructureRule.new)
