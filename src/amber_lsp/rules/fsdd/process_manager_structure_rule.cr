module AmberLSP::Rules::FSDD
  class ProcessManagerStructureRule < AmberLSP::Rules::BaseRule
    def id : String
      "fsdd/process-manager-structure"
    end

    def description : String
      "Process manager classes must define an initialize with typed parameters and a public perform or call method"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Warning
    end

    def applies_to : Array(String)
      ["src/**/process_managers/**", "src/**/processes/**"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      return [] of Diagnostic unless file_path.includes?("process_managers/") || file_path.includes?("processes/")

      diagnostics = [] of Diagnostic
      lines = content.lines

      # def initialize with at least one typed parameter: matches ( ... : ... )
      init_typed_re = /^\s*def\s+initialize\s*\([^)]*:[^)]*\)/
      # Public def perform or call; private def perform|call is excluded
      perform_re         = /^\s*def\s+(perform|call)\b/
      private_perform_re = /^\s*private\s+def\s+(perform|call)\b/

      has_typed_init = lines.any? { |line| init_typed_re.matches?(line) }
      has_public_perform = lines.any? do |line|
        perform_re.matches?(line) && !private_perform_re.matches?(line)
      end

      return [] of Diagnostic if has_typed_init && has_public_perform

      content.each_line.with_index do |line, line_number|
        match = /^\s*class\s+(\w[\w:]*)/.match(line)
        next unless match

        class_name = match[1]
        start_char = (match.begin(1) || 0).to_i32
        end_char   = (match.end(1) || line.size).to_i32

        issues = [] of String
        issues << "missing initialize with typed parameters" unless has_typed_init
        issues << "missing public perform or call method" unless has_public_perform

        diagnostics << Diagnostic.new(
          range: TextRange.new(
            Position.new(line_number.to_i32, start_char),
            Position.new(line_number.to_i32, end_char)
          ),
          severity: default_severity,
          code: id,
          message: "Process manager '#{class_name}': #{issues.join(", ")}"
        )
      end

      diagnostics
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::FSDD::ProcessManagerStructureRule.new)
