module AmberLSP::Rules::Library
  # Requires collars for changed methods with behavioral branches.
  class ChangedMethodCollar < AmberLSP::Rules::BaseRule
    # Returns this rule's stable identifier.
    def id : String
      "library/changed-method-collar"
    end

    # Describes the changed method collar policy.
    def description : String
      "Requires golden and boundary collars for changed behavioral methods"
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

    # Leaves ordinary file checks empty; collar analysis needs the project graph.
    def check(file_path : String, content : String) : Support::ListOfDiagnostics
      return [] of AmberLSP::Rules::Diagnostic unless file_path.ends_with?(".cr")
      return [] of AmberLSP::Rules::Diagnostic if content.empty?

      [] of AmberLSP::Rules::Diagnostic
    end

    # :nodoc:
    def check_project(
      root_path : String,
      list_of_target_paths : Support::ListOfStrings,
      changed_lines : Support::GitChangedLines,
      list_of_carried_in_prefixes : Support::ListOfStrings,
    ) : Support::ListOfDiagnostics
      Support::AnalyzeChangedMethodCollars.new(
        root_path,
        list_of_target_paths,
        changed_lines,
        list_of_carried_in_prefixes,
      ).perform
    end
  end
end
