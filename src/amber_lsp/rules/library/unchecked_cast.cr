module AmberLSP::Rules::Library
  # Reports unchecked casts to named types.
  class UncheckedCast < AmberLSP::Rules::BaseRule
    MESSAGE = "Use a checked cast or narrow the value before casting"

    # Returns this rule's stable identifier.
    def id : String
      "library/unchecked-cast"
    end

    # Describes the unchecked cast policy.
    def description : String
      "Disallows unchecked casts to named types"
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

    # Reports `.as(T)` casts to named types.
    def check(file_path : String, content : String) : Support::ListOfDiagnostics
      return [] of AmberLSP::Rules::Diagnostic unless file_path.ends_with?(".cr")

      syntax_tree = Support::ParseCrystalSource.new(content).perform
      return [] of AmberLSP::Rules::Diagnostic unless syntax_tree

      list_of_diagnostics = [] of AmberLSP::Rules::Diagnostic
      Support::CollectTypeCasts.new(syntax_tree).perform.each do |cast_node|
        next if cast_node.obj.is_a?(Crystal::NilLiteral)
        next unless named_type?(cast_node.to)

        if diagnostic = Support::CreateDiagnosticForASTNode.new(
             cast_node,
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

    private def named_type?(type_node : Crystal::ASTNode) : Bool
      return true if type_node.is_a?(Crystal::Path)
      return false unless generic_node = type_node.as?(Crystal::Generic)

      generic_node.suffix != Crystal::Generic::Suffix::Asterisk && generic_node.name.is_a?(Crystal::Path)
    end
  end
end
