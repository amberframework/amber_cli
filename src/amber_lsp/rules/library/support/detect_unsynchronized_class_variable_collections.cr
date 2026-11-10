require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Detects collection-valued class variables without file-level synchronization.
  class DetectUnsynchronizedClassVariableCollections < Crystal::Visitor
    getter list_of_findings = [] of Crystal::ASTNode
    getter? has_synchronization_primitive = false

    # Initializes the detector with *root_node*.
    def initialize(@root_node : Crystal::ASTNode)
    end

    # Collects collection-valued class variables and synchronization markers.
    def perform : DetectUnsynchronizedClassVariableCollections
      @root_node.accept(self)
      self
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # :nodoc:
    def visit(node : Crystal::Path) : Bool
      last_name = node.names.last?
      @has_synchronization_primitive = true if last_name.try(&.in?(%w[Mutex Atomic]))
      true
    end

    # :nodoc:
    def visit(node : Crystal::Assign) : Bool
      if node.target.is_a?(Crystal::ClassVar) && collection_value?(node.value)
        list_of_findings << node
      end
      true
    end

    # :nodoc:
    def visit(node : Crystal::TypeDeclaration) : Bool
      if node.var.is_a?(Crystal::ClassVar) && collection_type?(node.declared_type)
        list_of_findings << node
      end
      true
    end

    private def collection_value?(node : Crystal::ASTNode) : Bool
      return true if node.is_a?(Crystal::ArrayLiteral) || node.is_a?(Crystal::HashLiteral)
      return false unless call_node = node.as?(Crystal::Call)

      collection_type?(call_node.obj) || (call_node.obj.nil? && call_node.name.in?(%w[Array Hash Set]))
    end

    private def collection_type?(node : Crystal::ASTNode?) : Bool
      return false unless node
      return node.names.last?.try(&.in?(%w[Array Hash Set])) || false if node.is_a?(Crystal::Path)
      return collection_type?(node.name) if node.is_a?(Crystal::Generic)

      false
    end
  end
end
