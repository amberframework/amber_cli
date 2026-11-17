require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Collects receiverless and `self` calls from one method body.
  class CollectCallsWithinMethodBody < Crystal::Visitor
    getter list_of_called_method_names = [] of String

    # Initializes the collector with *method_body*.
    def initialize(@method_body : Crystal::ASTNode)
    end

    # Collects eligible call names from *method_body*.
    def perform : ListOfStrings
      @method_body.accept(self)
      list_of_called_method_names.uniq
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    # Leaves nested type and method bodies outside the caller's edges.
    def visit(node : Crystal::Def | Crystal::ClassDef | Crystal::ModuleDef | Crystal::EnumDef) : Bool
      false
    end

    # Collects a receiverless call or a call whose receiver is `self`.
    def visit(node : Crystal::Call) : Bool
      if node.obj.nil? || self_receiver?(node.obj)
        list_of_called_method_names << node.name
      end
      true
    end

    private def self_receiver?(receiver : Crystal::ASTNode?) : Bool
      return false unless receiver_node = receiver.as?(Crystal::Var)

      receiver_node.name == "self"
    end
  end
end
