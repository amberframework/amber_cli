module AmberLSP::Rules::Library
  # Reports paths that disable certificate verification.
  class DisabledCertificateVerification < AmberLSP::Rules::BaseRule
    MESSAGE = "Keep certificate verification enabled"

    # Returns this rule's stable identifier.
    def id : String
      "library/disabled-certificate-verification"
    end

    # Describes the certificate verification policy.
    def description : String
      "Disallows disabling certificate verification"
    end

    # Returns the default blocking severity.
    def default_severity : AmberLSP::Rules::Severity
      AmberLSP::Rules::Severity::Warning
    end

    # Selects library source files.
    def applies_to : Support::ListOfStrings
      ["src/**"]
    end

    # Keeps the rule out of editor diagnostics for Amber applications.
    def requires_amber_project? : Bool
      false
    end

    # Reports paths that end in `VerifyMode::NONE`.
    def check(file_path : String, content : String) : Support::ListOfDiagnostics
      return [] of AmberLSP::Rules::Diagnostic unless file_path.ends_with?(".cr")

      syntax_tree = Support::ParseCrystalSource.new(content).perform
      return [] of AmberLSP::Rules::Diagnostic unless syntax_tree

      list_of_diagnostics = [] of AmberLSP::Rules::Diagnostic
      Support::CollectPathsFromCrystalAST.new(syntax_tree).perform.each do |path_node|
        next unless path_node.names.size >= 2
        next unless path_node.names[-2..-1] == %w[VerifyMode NONE]

        if diagnostic = Support::CreateDiagnosticForASTNode.new(
             path_node,
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
  end
end
