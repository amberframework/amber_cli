module AmberLSP::Rules::Library
  # Reports direct environment access in library source.
  class EnvironmentRead < AmberLSP::Rules::BaseRule
    MESSAGE = "Read environment variables at the application boundary"

    # Returns this rule's stable identifier.
    def id : String
      "library/environment-read"
    end

    # Describes the environment boundary policy.
    def description : String
      "Disallows environment reads inside library code"
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

    # Reports calls made through the global `ENV` path.
    def check(file_path : String, content : String) : Support::ListOfDiagnostics
      return [] of AmberLSP::Rules::Diagnostic unless file_path.ends_with?(".cr")

      syntax_tree = Support::ParseCrystalSource.new(content).perform
      return [] of AmberLSP::Rules::Diagnostic unless syntax_tree

      list_of_diagnostics = [] of AmberLSP::Rules::Diagnostic
      Support::CollectCrystalMethodCalls.new(syntax_tree).perform.each do |call_node|
        receiver_path = call_node.obj.as?(Crystal::Path)
        next unless receiver_path && receiver_path.names == ["ENV"]

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
  end
end
