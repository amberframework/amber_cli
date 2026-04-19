module AmberLSP::Rules::Specs
  class SpecExistenceRule < AmberLSP::Rules::BaseRule
    def id : String
      "amber/spec-existence"
    end

    def description : String
      "Each controller file should have a corresponding spec file"
    end

    def default_severity : AmberLSP::Rules::Severity
      Severity::Information
    end

    def applies_to : Array(String)
      ["src/controllers/*"]
    end

    def check(file_path : String, content : String) : Array(Diagnostic)
      return [] of Diagnostic unless file_path.includes?("controllers/")

      # Skip application_controller.cr
      basename = File.basename(file_path)
      return [] of Diagnostic if basename == "application_controller.cr"

      diagnostics = [] of Diagnostic

      # Convert src/controllers/posts_controller.cr -> spec/controllers/posts_controller_spec.cr
      spec_path = file_path
        .sub("src/controllers/", "spec/controllers/")
        .sub(/\.cr$/, "_spec.cr")

      unless File.exists?(spec_path)
        diagnostics << Diagnostic.new(
          range: TextRange.new(
            Position.new(0_i32, 0_i32),
            Position.new(0_i32, 0_i32)
          ),
          severity: default_severity,
          code: id,
          message: "Missing spec file: expected '#{spec_path}' to exist"
        )
      end

      diagnostics
    end
  end
end

AmberLSP::Rules::RuleRegistry.register(AmberLSP::Rules::Specs::SpecExistenceRule.new)
