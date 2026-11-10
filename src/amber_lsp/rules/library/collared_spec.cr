module AmberLSP::Rules::Library
  # Requires golden and boundary cases for behavior describes in specs.
  class CollaredSpec < AmberLSP::Rules::BaseRule
    # Returns this rule's stable identifier.
    def id : String
      "library/collared-spec"
    end

    # Describes the collared spec shape.
    def description : String
      "Requires golden and collared cases in method behavior specs"
    end

    # Returns the default blocking severity.
    def default_severity : AmberLSP::Rules::Severity
      AmberLSP::Rules::Severity::Warning
    end

    # Selects spec source files.
    def applies_to : Support::ListOfStrings
      ["spec/**"]
    end

    # Keeps the rule out of editor diagnostics for Amber applications.
    def requires_amber_project? : Bool
      false
    end

    # Reports method behavior describes that miss a golden case or boundary collar.
    def check(file_path : String, content : String) : Support::ListOfDiagnostics
      return [] of AmberLSP::Rules::Diagnostic unless spec_file?(file_path)

      syntax_tree = Support::ParseCrystalSource.new(content).perform
      return [] of AmberLSP::Rules::Diagnostic unless syntax_tree

      list_of_diagnostics = [] of AmberLSP::Rules::Diagnostic
      Support::CollectBehaviorDescribes.new(syntax_tree).perform.each do |describe_call|
        shape = Support::CollaredSpecShape.new(content, describe_call)
        shape.list_of_missing_parts.each do |missing_part|
          if diagnostic = Support::CreateDiagnosticForASTNode.new(
               describe_call,
               content,
               id,
               default_severity,
               missing_part,
             ).perform
            list_of_diagnostics << diagnostic
          end
        end
      end
      list_of_diagnostics
    end

    private def spec_file?(file_path : String) : Bool
      file_path.starts_with?("spec/") || file_path.includes?("/spec/")
    end
  end
end
