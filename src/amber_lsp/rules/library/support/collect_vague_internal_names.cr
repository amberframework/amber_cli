require "compiler/crystal/syntax"
require "set"

module AmberLSP::Rules::Library::Support
  # Collects vague local names, block parameters, and private method parameters.
  class CollectVagueInternalNames < Crystal::Visitor
    VAGUE_NAMES = %w[tmp temp val vals res ret retval obj arr ary lst str num idx info data item items stuff thing things m x y z]

    getter list_of_findings = [] of Tuple(Crystal::ASTNode, String)

    # Initializes the collector with *root_node*.
    def initialize(@root_node : Crystal::ASTNode)
      @list_of_argument_names_by_scope = [] of Set(String)
      @list_of_local_names_by_scope = [] of Set(String)
      start_scope
    end

    # Collects vague names from *root_node*.
    def perform : ListOfVagueNameFindings
      @root_node.accept(self)
      list_of_findings
    end

    # Applies explicit visibility before visiting a method definition.
    def visit(node : Crystal::VisibilityModifier) : Bool
      expression = node.exp
      if expression.is_a?(Crystal::Def)
        expression.visibility = node.modifier
      end
      true
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # Starts the local and argument scopes for a method definition.
    def visit(node : Crystal::Def) : Bool
      start_scope
      node.args.each do |argument_node|
        add_argument_name(argument_node.name)
        if node.visibility.private? || node.name == "->"
          record_vague_name(argument_node, argument_node.name)
        end
      end
      if block_argument = node.block_arg
        add_argument_name(block_argument.name)
        if node.visibility.private?
          record_vague_name(block_argument, block_argument.name)
        end
      end
      true
    end

    # Ends the local and argument scopes for a method definition.
    def end_visit(node : Crystal::Def) : Nil
      finish_scope
    end

    # Starts a local scope and checks its block parameters.
    def visit(node : Crystal::Block) : Bool
      start_scope
      node.args.each do |argument_node|
        add_argument_name(argument_node.name)
        record_vague_name(argument_node, argument_node.name)
      end
      true
    end

    # Ends the local scope for a block.
    def end_visit(node : Crystal::Block) : Nil
      finish_scope
    end

    # Collects a vague local assignment target once per scope.
    def visit(node : Crystal::Assign) : Bool
      if local_variable = node.target.as?(Crystal::Var)
        record_local_variable(local_variable)
      end
      true
    end

    private def start_scope : Nil
      @list_of_argument_names_by_scope << Set(String).new
      @list_of_local_names_by_scope << Set(String).new
    end

    private def finish_scope : Nil
      @list_of_argument_names_by_scope.pop
      @list_of_local_names_by_scope.pop
    end

    private def add_argument_name(argument_name : String) : Nil
      if argument_names = @list_of_argument_names_by_scope.last?
        argument_names << argument_name
      end
    end

    private def record_local_variable(local_variable : Crystal::Var) : Nil
      local_name = local_variable.name
      return unless vague_name?(local_name)

      argument_names = @list_of_argument_names_by_scope.last?
      return if argument_names && argument_names.includes?(local_name)
      return unless local_names = @list_of_local_names_by_scope.last?
      return if local_names.includes?(local_name)

      local_names << local_name
      list_of_findings << {local_variable, local_name}
    end

    private def record_vague_name(node : Crystal::ASTNode, name : String) : Nil
      return unless vague_name?(name)

      list_of_findings << {node, name}
    end

    private def vague_name?(name : String) : Bool
      return false if name.starts_with?("_")
      return true if VAGUE_NAMES.includes?(name)

      name.size == 1 && !name.in?(%w[i j k])
    end
  end
end
