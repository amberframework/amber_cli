module AmberLSP::Rules::Library
  # Reports vague local names, block parameters, and private method parameters.
  class VagueInternalName < AmberLSP::Rules::BaseRule
    MESSAGE = "Use a descriptive internal name instead of `%s`"

    # Returns this rule's stable identifier.
    def id : String
      "library/vague-internal-name"
    end

    # Describes the internal naming policy.
    def description : String
      "Suggests descriptive names for internal variables and parameters"
    end

    # Returns the default advisory severity.
    def default_severity : AmberLSP::Rules::Severity
      AmberLSP::Rules::Severity::Information
    end

    # Selects library source files.
    def applies_to : Support::ListOfStrings
      ["src/**"]
    end

    # Keeps the rule out of editor diagnostics for Amber applications.
    def requires_amber_project? : Bool
      false
    end

    # Reports vague internal variable and parameter names.
    def check(file_path : String, content : String) : Support::ListOfDiagnostics
      return [] of AmberLSP::Rules::Diagnostic unless file_path.ends_with?(".cr")

      syntax_tree = Support::ParseCrystalSource.new(content).perform
      return [] of AmberLSP::Rules::Diagnostic unless syntax_tree

      list_of_diagnostics = [] of AmberLSP::Rules::Diagnostic
      Support::CollectVagueInternalNames.new(syntax_tree).perform.each do |node, variable_name|
        if diagnostic = Support::CreateDiagnosticForASTNode.new(
             node,
             content,
             id,
             default_severity,
             MESSAGE % variable_name,
           ).perform
          list_of_diagnostics << diagnostic
        end
      end
      list_of_diagnostics
    end
  end
end
