module AmberLSP::Rules::Library
  # Reports direct reopenings of standard library types.
  class StdlibReopen < AmberLSP::Rules::BaseRule
    CORE_TYPE_NAMES = %w[String Array Hash Object Nil Symbol Int32 Int64 Float64 Time Enumerable Number]
    MESSAGE         = "Avoid reopening core type `%s`"

    # Returns this rule's stable identifier.
    def id : String
      "library/stdlib-reopen"
    end

    # Describes the core type reopening policy.
    def description : String
      "Disallows reopening configured core types"
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

    # Reports top-level class or module definitions that reopen core types.
    def check(file_path : String, content : String) : Support::ListOfDiagnostics
      return [] of AmberLSP::Rules::Diagnostic unless file_path.ends_with?(".cr")

      syntax_tree = Support::ParseCrystalSource.new(content).perform
      return [] of AmberLSP::Rules::Diagnostic unless syntax_tree

      list_of_diagnostics = [] of AmberLSP::Rules::Diagnostic
      reopens = Support::CollectCoreTypeReopens.new(syntax_tree, CORE_TYPE_NAMES).perform
      reopens.each do |node, type_name|
        if diagnostic = Support::CreateDiagnosticForASTNode.new(
             node,
             content,
             id,
             default_severity,
             MESSAGE % type_name,
           ).perform
          list_of_diagnostics << diagnostic
        end
      end
      list_of_diagnostics
    end
  end
end
