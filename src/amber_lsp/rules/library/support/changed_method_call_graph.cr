require "set"

module AmberLSP::Rules::Library::Support
  # Indexes calls between methods declared on the same reopened type.
  class ChangedMethodCallGraph
    # Initializes the graph from method definitions collected across source files.
    def initialize(@list_of_method_definitions : ListOfMethodDefinitions)
      @list_of_method_definitions_by_key = Hash(String, ListOfMethodDefinitions).new
      @list_of_callers_by_method_key = Hash(String, ListOfMethodDefinitions).new
      @list_of_caller_identities_by_method_key = Hash(String, Set(String)).new
      index_method_definitions
      index_method_callers
    end

    # Returns methods of the same type that call *method_definition*.
    def callers_for(method_definition : MethodDefinition) : ListOfMethodDefinitions
      @list_of_callers_by_method_key[method_definition.method_key]?.try(&.dup) || [] of MethodDefinition
    end

    private def index_method_definitions : Nil
      @list_of_method_definitions.each do |method_definition|
        method_key = method_definition.method_key
        list_of_definitions = @list_of_method_definitions_by_key[method_key]?
        unless list_of_definitions
          list_of_definitions = [] of MethodDefinition
          @list_of_method_definitions_by_key[method_key] = list_of_definitions
        end
        list_of_definitions << method_definition
      end
    end

    private def index_method_callers : Nil
      @list_of_method_definitions.each do |caller_definition|
        caller_definition.list_of_called_method_names.each do |called_method_name|
          method_key = method_key_for(caller_definition, called_method_name)
          callee_definitions = @list_of_method_definitions_by_key[method_key]?
          next unless callee_definitions

          callee_definitions.each do |callee_definition|
            add_caller(callee_definition.method_key, caller_definition)
          end
        end
      end
    end

    private def method_key_for(method_definition : MethodDefinition, method_name : String) : String
      method_kind = method_definition.class_method? ? "class" : "instance"
      "#{method_definition.owner_type_name}::#{method_kind}::#{method_name}"
    end

    private def add_caller(method_key : String, caller_definition : MethodDefinition) : Nil
      list_of_identities = @list_of_caller_identities_by_method_key[method_key]?
      unless list_of_identities
        list_of_identities = Set(String).new
        @list_of_caller_identities_by_method_key[method_key] = list_of_identities
      end
      return if list_of_identities.includes?(caller_definition.definition_identity)

      list_of_identities << caller_definition.definition_identity
      list_of_callers = @list_of_callers_by_method_key[method_key]?
      unless list_of_callers
        list_of_callers = [] of MethodDefinition
        @list_of_callers_by_method_key[method_key] = list_of_callers
      end
      list_of_callers << caller_definition
    end
  end
end
