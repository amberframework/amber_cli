module AmberLSP::Rules::Library
  # Reports documented public methods without an explicit return type.
  class PublicReturnType < AmberLSP::Rules::BaseRule
    MESSAGE                = "Add an explicit return type to this public definition"
    LIFECYCLE_METHOD_NAMES = %w[initialize finalize]

    # Returns this rule's stable identifier.
    def id : String
      "library/public-return-type"
    end

    # Describes the public return type policy.
    def description : String
      "Requires explicit return types on documented public methods"
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

    # Reports public methods that omit a return type annotation.
    def check(file_path : String, content : String) : Support::ListOfDiagnostics
      return [] of AmberLSP::Rules::Diagnostic unless file_path.ends_with?(".cr")

      syntax_tree = Support::ParseCrystalSource.new(content).perform
      return [] of AmberLSP::Rules::Diagnostic unless syntax_tree

      list_of_diagnostics = [] of AmberLSP::Rules::Diagnostic
      method_nodes = Support::CollectPublicMethods.new(syntax_tree, content).perform
      method_nodes.each do |method_node|
        next if LIFECYCLE_METHOD_NAMES.includes?(method_node.name)
        next if method_node.return_type

        if diagnostic = Support::CreateDiagnosticForASTNode.new(
             method_node,
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
