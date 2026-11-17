module AmberLSP::Rules::Library
  # Reports raised strings so libraries can use named error types.
  class TypedRaise < AmberLSP::Rules::BaseRule
    MESSAGE = "Raise a named error instead of a string message"

    # Returns this rule's stable identifier.
    def id : String
      "library/typed-raise"
    end

    # Describes the raised-string policy.
    def description : String
      "Disallows raising string messages instead of named errors"
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

    # Reports receiverless raises whose first argument is a string.
    def check(file_path : String, content : String) : Support::ListOfDiagnostics
      return [] of AmberLSP::Rules::Diagnostic unless file_path.ends_with?(".cr")

      syntax_tree = Support::ParseCrystalSource.new(content).perform
      return [] of AmberLSP::Rules::Diagnostic unless syntax_tree

      list_of_diagnostics = [] of AmberLSP::Rules::Diagnostic
      Support::CollectTypedRaiseCalls.new(syntax_tree).perform.each do |raise_call|
        first_argument = raise_call.args.first?
        next unless first_argument.is_a?(Crystal::StringLiteral) || first_argument.is_a?(Crystal::StringInterpolation)

        if diagnostic = Support::CreateDiagnosticForASTNode.new(
             raise_call,
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
