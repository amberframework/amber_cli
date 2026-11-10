require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Collects top-level reopenings of configured core classes and modules.
  class CollectCoreTypeReopens < Crystal::Visitor
    getter list_of_reopens = [] of Tuple(Crystal::ASTNode, String)

    # Initializes the collector with *root_node* and core type names.
    def initialize(@root_node : Crystal::ASTNode, @list_of_core_type_names : Array(String))
      @list_of_enclosing_type_names = [] of String
    end

    # Collects core type reopenings from *root_node*.
    def perform : ListOfCoreTypeReopens
      @root_node.accept(self)
      list_of_reopens
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # Collects class definitions that reopen a configured core type.
    def visit(node : Crystal::ClassDef) : Bool
      collect_reopening(node, node.name)
      @list_of_enclosing_type_names << node.name.names.join("::")
      true
    end

    # Collects module definitions that reopen a configured core type.
    def visit(node : Crystal::ModuleDef) : Bool
      collect_reopening(node, node.name)
      @list_of_enclosing_type_names << node.name.names.join("::")
      true
    end

    # Leaves the enclosing class scope after visiting its body.
    def end_visit(node : Crystal::ClassDef) : Nil
      @list_of_enclosing_type_names.pop
    end

    # Leaves the enclosing module scope after visiting its body.
    def end_visit(node : Crystal::ModuleDef) : Nil
      @list_of_enclosing_type_names.pop
    end

    private def collect_reopening(node : Crystal::ASTNode, name_path : Crystal::Path) : Nil
      full_name = name_path.names.join("::")
      return unless @list_of_core_type_names.includes?(full_name)
      return if name_path.names.size == 1 && !name_path.global? && !@list_of_enclosing_type_names.empty?

      list_of_reopens << {node, full_name}
    end
  end
end
