require "set"

module AmberLSP::Rules::Library::Support
  # Checks changed methods against collars on their public callers.
  class AnalyzeChangedMethodCollars
    RULE_ID = "library/changed-method-collar"

    NO_PUBLIC_CALLER_MESSAGE = "The nearest public entry point needs a describe with a direct golden `it` or `context` case, an `at the boundary` context, and a `just past the boundary` context with an expected-failure assertion."

    # Initializes the analysis with project paths, changed lines, and carry-in prefixes.
    def initialize(
      @root_path : String,
      @list_of_target_paths : ListOfStrings,
      @changed_lines : GitChangedLines,
      @list_of_carried_in_prefixes : ListOfStrings,
    )
      @list_of_target_paths_as_set = @list_of_target_paths.to_set
    end

    # Checks changed behavior methods against matching public caller specs.
    def perform : ListOfDiagnostics
      list_of_method_definitions = index_all_source_methods
      call_graph = ChangedMethodCallGraph.new(list_of_method_definitions)
      list_of_behavior_describes = ReadBehaviorDescribes.new(@root_path).perform
      list_of_diagnostics = [] of AmberLSP::Rules::Diagnostic

      list_of_method_definitions.each do |method_definition|
        next unless changed_behavior_method?(method_definition)
        next if carried_in_path?(method_definition.relative_path)

        message = message_for_changed_method(method_definition, call_graph, list_of_behavior_describes)
        next unless message

        if diagnostic = CreateDiagnosticForASTNode.new(
             method_definition.method_node,
             method_definition.source_code,
             RULE_ID,
             AmberLSP::Rules::Severity::Warning,
             message,
             method_definition.relative_path,
           ).perform
          list_of_diagnostics << diagnostic
        end
      end
      list_of_diagnostics
    end

    private def index_all_source_methods : ListOfMethodDefinitions
      list_of_method_definitions = [] of MethodDefinition
      source_pattern = File.join(@root_path, "src", "**", "*.cr")

      Dir.glob(source_pattern).sort.each do |absolute_path|
        relative_path = Path[absolute_path].relative_to(Path[@root_path]).to_s
        source_code = File.read(absolute_path)
        syntax_tree = ParseCrystalSource.new(source_code).perform
        next unless syntax_tree

        method_definitions = IndexMethodsFromSource.new(
          syntax_tree,
          relative_path,
          source_code,
          @changed_lines,
        ).perform
        list_of_method_definitions.concat(method_definitions)
      end
      list_of_method_definitions
    end

    private def changed_behavior_method?(method_definition : MethodDefinition) : Bool
      return false unless @list_of_target_paths_as_set.includes?(method_definition.relative_path)
      return false unless method_definition.changed_behavior_method?

      method_definition.visibility.public? || method_definition.private_or_protected?
    end

    private def message_for_changed_method(
      method_definition : MethodDefinition,
      call_graph : ChangedMethodCallGraph,
      list_of_behavior_describes : ListOfBehaviorDescribes,
    ) : String?
      if line_number = method_definition.method_node.location.try(&.line_number)
        exemption_reason = ReadSourceAnnotations.new(method_definition.source_code).collar_exemption_reason_at(line_number)
        return if exemption_reason && !exemption_reason.empty?
      end

      return message_for_public_method(method_definition, list_of_behavior_describes) if method_definition.public_caller?

      message_for_private_or_protected_method(method_definition, call_graph, list_of_behavior_describes)
    end

    private def message_for_public_method(
      method_definition : MethodDefinition,
      list_of_behavior_describes : ListOfBehaviorDescribes,
    ) : String?
      list_of_matching_describes = matching_describes(method_definition.selector, list_of_behavior_describes)
      return "Method #{method_definition.selector} has no matching describe" if list_of_matching_describes.empty?
      return if any_describe_has_collar?(list_of_matching_describes)

      closest_shape = closest_shape(list_of_matching_describes)
      "Method #{method_definition.selector} is missing: #{closest_shape.list_of_missing_parts.join("; ")}"
    end

    private def message_for_private_or_protected_method(
      method_definition : MethodDefinition,
      call_graph : ChangedMethodCallGraph,
      list_of_behavior_describes : ListOfBehaviorDescribes,
    ) : String?
      list_of_public_callers = public_callers_for(method_definition, call_graph)
      return "Changed method #{method_definition.selector} has no public caller in this type; #{NO_PUBLIC_CALLER_MESSAGE}" if list_of_public_callers.empty?

      return if list_of_public_callers.any? do |caller_definition|
                  any_describe_has_collar?(matching_describes(caller_definition.selector, list_of_behavior_describes))
                end

      list_of_caller_names = [] of String
      list_of_caller_details = [] of String
      list_of_public_callers.each do |caller_definition|
        selector = caller_definition.selector
        list_of_caller_names << selector unless list_of_caller_names.includes?(selector)
        list_of_matching_describes = matching_describes(selector, list_of_behavior_describes)
        if list_of_matching_describes.empty?
          missing_parts = [
            "Add a matching describe for #{selector}",
            CollaredSpecShape::MSG_GOLDEN_CASE,
            CollaredSpecShape::MSG_BOUNDARY_CONTEXT,
            CollaredSpecShape::MSG_PAST_BOUNDARY_CONTEXT,
            CollaredSpecShape::MSG_EXPECTED_FAILURE,
          ]
          list_of_caller_details << "#{selector}: #{missing_parts.join("; ")}"
        else
          shape = closest_shape(list_of_matching_describes)
          list_of_caller_details << "#{selector}: #{shape.list_of_missing_parts.join("; ")}"
        end
      end

      "Changed method #{method_definition.selector} is called by public callers #{list_of_caller_names.join(", ")}; missing collar parts: #{list_of_caller_details.join("; ")}"
    end

    private def public_callers_for(
      method_definition : MethodDefinition,
      call_graph : ChangedMethodCallGraph,
    ) : ListOfMethodDefinitions
      list_of_public_callers = [] of MethodDefinition
      list_of_pending_methods = [method_definition]
      list_of_visited_definitions = Set(String).new

      until list_of_pending_methods.empty?
        current_method = list_of_pending_methods.pop
        next if list_of_visited_definitions.includes?(current_method.definition_identity)

        list_of_visited_definitions << current_method.definition_identity
        call_graph.callers_for(current_method).each do |caller_definition|
          next unless caller_definition.owner_type_name == method_definition.owner_type_name

          if caller_definition.public_caller?
            unless list_of_public_callers.any? { |public_caller| public_caller.definition_identity == caller_definition.definition_identity }
              list_of_public_callers << caller_definition
            end
          elsif caller_definition.has_public_type?
            list_of_pending_methods << caller_definition
          end
        end
      end

      list_of_public_callers
    end

    private def matching_describes(
      selector : String,
      list_of_behavior_describes : ListOfBehaviorDescribes,
    ) : ListOfBehaviorDescribes
      list_of_behavior_describes.select(&.selector.==(selector))
    end

    private def any_describe_has_collar?(list_of_describes : ListOfBehaviorDescribes) : Bool
      list_of_describes.any?(&.shape.satisfied?)
    end

    private def closest_shape(list_of_describes : ListOfBehaviorDescribes) : CollaredSpecShape
      shapes = list_of_describes.map(&.shape)
      shapes.min_by(&.list_of_missing_parts.size)
    end

    private def carried_in_path?(relative_path : String) : Bool
      @list_of_carried_in_prefixes.any? do |path_prefix|
        normalized_prefix = path_prefix.lchop("./").rstrip('/')
        normalized_prefix.empty? || relative_path == normalized_prefix || relative_path.starts_with?("#{normalized_prefix}/")
      end
    end
  end
end
