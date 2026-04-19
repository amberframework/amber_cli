module AmberLSP::Rules::FileNaming
  class SnakeCaseRule < AmberLSP::Rules::BaseRule
    def id : String
      "amber/file-naming"
    end

    def description : String
      "Crystal file names must use snake_case"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Warning
    end

    def applies_to : Array(String)
      ["*.cr"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      diagnostics = [] of Diagnostic

      basename = File.basename(file_path)

      # Skip hidden files
      return diagnostics if basename.starts_with?(".")

      snake_case_pattern = /^[a-z][a-z0-9_]*\.cr$/

      unless snake_case_pattern.matches?(basename)
        suggested = suggest_snake_case(basename)

        diagnostics << Diagnostic.new(
          range: TextRange.new(
            Position.new(0_i32, 0_i32),
            Position.new(0_i32, 0_i32)
          ),
          severity: default_severity,
          code: id,
          message: "File name '#{basename}' is not snake_case. Consider renaming to '#{suggested}'"
        )
      end

      diagnostics
    end

    private def suggest_snake_case(basename : String) : String
      name = basename.sub(/\.cr$/, "")
      # Convert PascalCase/camelCase to snake_case
      snake = name.gsub(/([A-Z])/) { |match, m| "_#{m[0].downcase}" }.lstrip('_')
      # Replace hyphens and spaces with underscores
      snake = snake.gsub(/[-\s]+/, "_")
      # Collapse multiple underscores
      snake = snake.gsub(/_+/, "_")
      # Lowercase everything
      snake = snake.downcase
      "#{snake}.cr"
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::FileNaming::SnakeCaseRule.new)
