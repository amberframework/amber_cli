require "set"

module AmberLSP::Rules::Library
  # Requires a spec selector for each public method with arguments.
  class PublicMethodHasSpec < AmberLSP::Rules::BaseRule
    MESSAGE = "Add a `describe \"#%s\"` or `describe \".%s\"` spec"

    @list_of_method_spec_selectors : Set(String)? = nil

    # Initializes the rule with the project root used to index specs.
    def initialize(@project_root : String)
    end

    # Returns this rule's stable identifier.
    def id : String
      "library/public-method-has-spec"
    end

    # Describes the public method spec policy.
    def description : String
      "Requires a method describe selector for public methods with arguments"
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

    # Reports public methods with arguments that have no method selector in specs.
    def check(file_path : String, content : String) : Support::ListOfDiagnostics
      return [] of AmberLSP::Rules::Diagnostic unless file_path.starts_with?("src/")

      syntax_tree = Support::ParseCrystalSource.new(content).perform
      return [] of AmberLSP::Rules::Diagnostic unless syntax_tree

      list_of_method_spec_selectors = method_spec_selectors
      list_of_diagnostics = [] of AmberLSP::Rules::Diagnostic
      Support::CollectPublicMethods.new(syntax_tree, content).perform.each do |method_node|
        next if method_node.name == "initialize"
        next if operator_method_name?(method_node.name)
        next unless method_takes_arguments?(method_node)
        next if method_spec_exists?(method_node.name, list_of_method_spec_selectors)

        if diagnostic = Support::CreateDiagnosticForASTNode.new(
             method_node,
             content,
             id,
             default_severity,
             MESSAGE % {method_node.name, method_node.name},
           ).perform
          list_of_diagnostics << diagnostic
        end
      end
      list_of_diagnostics
    end

    private def method_takes_arguments?(method_node : Crystal::Def) : Bool
      !method_node.args.empty? || !method_node.block_arg.nil?
    end

    private def method_spec_exists?(method_name : String, list_of_selectors : Set(String)) : Bool
      list_of_selectors.includes?("##{method_name}") || list_of_selectors.includes?(".#{method_name}")
    end

    private def operator_method_name?(method_name : String) : Bool
      method_name != "->" && method_name.each_char.none?(&.alphanumeric?)
    end

    private def method_spec_selectors : Set(String)
      if list_of_selectors = @list_of_method_spec_selectors
        return list_of_selectors
      end

      list_of_selectors = Set(String).new
      spec_pattern = File.join(@project_root, "spec", "**", "*_spec.cr")
      Dir.glob(spec_pattern).each do |spec_path|
        source_code = File.read(spec_path)
        syntax_tree = Support::ParseCrystalSource.new(source_code).perform
        next unless syntax_tree

        selectors = Support::CollectMethodDescribeSelectors.new(syntax_tree).perform
        selectors.each { |selector| list_of_selectors << selector }
      end
      @list_of_method_spec_selectors = list_of_selectors
      list_of_selectors
    end
  end
end
