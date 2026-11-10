module AmberLSP::Rules::Library
  # Reports global Log setup calls inside library source.
  class LogSetup < AmberLSP::Rules::BaseRule
    MESSAGE            = "Configure global Log setup in the application"
    SETUP_METHOD_NAMES = %w[setup setup_from_env]

    # Returns this rule's stable identifier.
    def id : String
      "library/log-setup"
    end

    # Describes the global logging policy.
    def description : String
      "Disallows configuring global Log setup from a library"
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

    # Reports global `Log.setup` and `Log.setup_from_env` calls.
    def check(file_path : String, content : String) : Support::ListOfDiagnostics
      return [] of AmberLSP::Rules::Diagnostic unless file_path.ends_with?(".cr")

      syntax_tree = Support::ParseCrystalSource.new(content).perform
      return [] of AmberLSP::Rules::Diagnostic unless syntax_tree

      list_of_diagnostics = [] of AmberLSP::Rules::Diagnostic
      Support::CollectCrystalMethodCalls.new(syntax_tree).perform.each do |call_node|
        receiver_path = call_node.obj.as?(Crystal::Path)
        next unless receiver_path && receiver_path.names == ["Log"]
        next unless SETUP_METHOD_NAMES.includes?(call_node.name)

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
