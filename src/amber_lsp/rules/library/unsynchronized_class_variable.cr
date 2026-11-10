module AmberLSP::Rules::Library
  # Reports mutable collection class variables without synchronization primitives.
  class UnsynchronizedClassVariable < AmberLSP::Rules::BaseRule
    MESSAGE = "Guard mutable class variable collections with Mutex or Atomic"

    # Returns this rule's stable identifier.
    def id : String
      "library/unsynchronized-class-variable"
    end

    # Describes the shared collection policy.
    def description : String
      "Disallows unsynchronized collection-valued class variables"
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

    # Reports collection class variables when the file has no synchronization marker.
    def check(file_path : String, content : String) : Support::ListOfDiagnostics
      return [] of AmberLSP::Rules::Diagnostic unless file_path.ends_with?(".cr")

      syntax_tree = Support::ParseCrystalSource.new(content).perform
      return [] of AmberLSP::Rules::Diagnostic unless syntax_tree

      scan_result = Support::DetectUnsynchronizedClassVariableCollections.new(syntax_tree).perform
      return [] of AmberLSP::Rules::Diagnostic if scan_result.has_synchronization_primitive?

      list_of_diagnostics = [] of AmberLSP::Rules::Diagnostic
      scan_result.list_of_findings.each do |finding_node|
        if diagnostic = Support::CreateDiagnosticForASTNode.new(
             finding_node,
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
