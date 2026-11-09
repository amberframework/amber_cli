module AmberLSP::Rules::Library
  # Reports spec examples that contain no recognized assertion call.
  class SpecWithoutAssertion < AmberLSP::Rules::BaseRule
    ASSERTION_PREFIXES = %w[assert_ expect_ verify_]
    MESSAGE            = "Add an assertion to this `it` block"

    # Returns this rule's stable identifier.
    def id : String
      "library/spec-without-assertion"
    end

    # Describes the spec assertion policy.
    def description : String
      "Requires a recognized assertion in each spec example"
    end

    # Returns the default blocking severity.
    def default_severity : AmberLSP::Rules::Severity
      AmberLSP::Rules::Severity::Warning
    end

    # Selects spec source files.
    def applies_to : Support::ListOfStrings
      ["spec/**"]
    end

    # Keeps the rule out of editor diagnostics for Amber applications.
    def requires_amber_project? : Bool
      false
    end

    # Reports `it` blocks without a recognized assertion call.
    def check(file_path : String, content : String) : Support::ListOfDiagnostics
      return [] of AmberLSP::Rules::Diagnostic unless spec_file?(file_path)

      syntax_tree = Support::ParseCrystalSource.new(content).perform
      return [] of AmberLSP::Rules::Diagnostic unless syntax_tree

      list_of_diagnostics = [] of AmberLSP::Rules::Diagnostic
      Support::CollectCrystalMethodCalls.new(syntax_tree).perform.each do |call_node|
        next unless call_node.name == "it"
        next unless block_node = call_node.block
        next if Support::DetectSpecAssertion.new(block_node.body, ASSERTION_PREFIXES).perform?

        if diagnostic = Support::CreateDiagnosticForASTNode.new(
             call_node,
             content,
             id,
             default_severity,
             MESSAGE,
           ).perform
          list_of_diagnostics << diagnostic
        end
      end
      list_of_diagnostics
    end

    private def spec_file?(file_path : String) : Bool
      file_path.starts_with?("spec/") || file_path.includes?("/spec/")
    end
  end
end
