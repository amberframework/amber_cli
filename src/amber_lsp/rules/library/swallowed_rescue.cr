module AmberLSP::Rules::Library
  # Reports broad rescue clauses that swallow errors or discard their cause.
  class SwallowedRescue < AmberLSP::Rules::BaseRule
    MESSAGE       = "Reraise or rescue a specific error"
    CAUSE_MESSAGE = "Pass cause: when converting a broad rescue into a new error"

    # Returns this rule's stable identifier.
    def id : String
      "library/swallowed-rescue"
    end

    # Describes the broad rescue policy.
    def description : String
      "Disallows swallowing broad rescue failures or dropping their cause"
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

    # Reports untyped or `Exception` rescues that do not preserve the failure.
    def check(file_path : String, content : String) : Support::ListOfDiagnostics
      return [] of AmberLSP::Rules::Diagnostic unless file_path.ends_with?(".cr")

      syntax_tree = Support::ParseCrystalSource.new(content).perform
      return [] of AmberLSP::Rules::Diagnostic unless syntax_tree

      list_of_diagnostics = [] of AmberLSP::Rules::Diagnostic
      Support::CollectRescueClauses.new(syntax_tree).perform.each do |rescue_clause|
        next unless broad_rescue?(rescue_clause)

        list_of_raise_calls = Support::CollectReceiverlessRaiseCalls.new(rescue_clause.body).perform
        message = message_for_rescue(rescue_clause, list_of_raise_calls)
        next unless message

        if diagnostic = Support::CreateDiagnosticForASTNode.new(
             rescue_clause,
             content,
             id,
             default_severity,
             message,
           ).perform
          list_of_diagnostics << diagnostic
        end
      end
      list_of_diagnostics
    end

    private def broad_rescue?(rescue_clause : Crystal::Rescue) : Bool
      return true unless rescue_types = rescue_clause.types
      return true if rescue_types.empty?

      rescue_types.any? do |rescue_type|
        rescue_type.is_a?(Crystal::Path) && rescue_type.names == ["Exception"]
      end
    end

    private def message_for_rescue(
      rescue_clause : Crystal::Rescue,
      list_of_raise_calls : Support::ListOfCrystalCalls,
    ) : String?
      return MESSAGE if list_of_raise_calls.empty?
      return if list_of_raise_calls.all? { |raise_call| cause_preserved?(raise_call, rescue_clause.name) }

      CAUSE_MESSAGE
    end

    private def cause_preserved?(raise_call : Crystal::Call, rescue_name : String?) : Bool
      return true if bare_raise?(raise_call)
      return true if re_raises_rescued_value?(raise_call, rescue_name)

      Support::DetectCauseArgument.new(raise_call).perform?
    end

    private def bare_raise?(raise_call : Crystal::Call) : Bool
      raise_call.args.empty? && raise_call.named_args.try(&.empty?) != false
    end

    private def re_raises_rescued_value?(raise_call : Crystal::Call, rescue_name : String?) : Bool
      return false unless rescue_name
      return false unless raised_value = raise_call.args.first?
      return false unless variable = raised_value.as?(Crystal::Var)

      variable.name == rescue_name
    end
  end
end
