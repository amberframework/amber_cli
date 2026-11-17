require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Collects behavior describe calls from a Crystal syntax tree.
  class CollectBehaviorDescribes < Crystal::Visitor
    # Requires `::` because a one-word string such as "Behavior" is usually a
    # heading, and a heading must leave the enclosing type in place.
    NAMESPACED_TYPE_NAME_PATTERN = /\A(?:::[A-Z]\w*(?:::[A-Z]\w*)*|[A-Z]\w*(?:::[A-Z]\w*)+)\z/

    getter list_of_describes = [] of Crystal::Call
    @list_of_enclosing_type_names = [] of String
    @owner_type_name_by_node_id = {} of UInt64 => String

    # Initializes the collector with *root_node*.
    def initialize(@root_node : Crystal::ASTNode)
    end

    # Collects method behavior describes from *root_node*.
    def perform : ListOfCrystalCalls
      @root_node.accept(self)
      list_of_describes
    end

    # Returns the type named by the describe enclosing *describe_call*, if any.
    def owner_type_name_for(describe_call : Crystal::Call) : String?
      @owner_type_name_by_node_id[describe_call.object_id]?
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # :nodoc:
    def visit(node : Crystal::Call) : Bool
      if ReadBehaviorSelector.new(node).perform
        list_of_describes << node
        if enclosing_type_name = @list_of_enclosing_type_names.last?
          @owner_type_name_by_node_id[node.object_id] = enclosing_type_name
        end
      end
      if described_type_name = described_type_name_for(node)
        @list_of_enclosing_type_names << described_type_name
      end
      true
    end

    # :nodoc:
    def end_visit(node : Crystal::Call) : Nil
      @list_of_enclosing_type_names.pop if described_type_name_for(node)
    end

    private def described_type_name_for(node : Crystal::Call) : String?
      return unless node.name == "describe"
      return unless described_node = node.args.first?

      if described_node.is_a?(Crystal::Path)
        described_node.names.join("::")
      elsif described_node.is_a?(Crystal::StringLiteral) && described_node.value.matches?(NAMESPACED_TYPE_NAME_PATTERN)
        described_node.value.lchop("::")
      end
    end
  end
end
