module AmberLSP::Rules::Library
  # Reports direct process output calls in library source.
  class ProcessOutput < AmberLSP::Rules::BaseRule
    MESSAGE             = "Use library logging instead of process output"
    OUTPUT_METHOD_NAMES = %w[puts print printf p pp]

    # Returns this rule's stable identifier.
    def id : String
      "library/process-output"
    end

    # Describes the process output policy.
    def description : String
      "Disallows writing process output directly from a library"
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

    # Reports receiverless process output calls.
    def check(file_path : String, content : String) : Support::ListOfDiagnostics
      return [] of AmberLSP::Rules::Diagnostic unless file_path.ends_with?(".cr")

      syntax_tree = Support::ParseCrystalSource.new(content).perform
      return [] of AmberLSP::Rules::Diagnostic unless syntax_tree

      list_of_diagnostics = [] of AmberLSP::Rules::Diagnostic
      Support::CollectCrystalMethodCalls.new(syntax_tree).perform.each do |call_node|
        next unless call_node.obj.nil? && OUTPUT_METHOD_NAMES.includes?(call_node.name)

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
