require "set"
require "compiler/crystal/syntax"

module AmberLSP::LibraryRulePacks
  class VisitCrystalCallsOutsideRequiredBlocks < Crystal::Visitor
    getter list_of_calls_outside_required_blocks : Array(Crystal::Call)
    getter list_of_multitenant_model_names : Set(String)

    @list_of_class_names = [] of String
    @required_block_depth = 0
    @list_of_unscoped_model_names = [] of String
    @list_of_block_scope_changes = [] of {Bool, String?}
    @list_of_method_scope_snapshots = [] of {Int32, Array(String)}

    def initialize(
      @list_of_scoped_model_names : Set(String),
      @list_of_query_method_names : Array(String),
      @required_block_call_name : String,
      @escape_block_call_name : String,
      @model_macro_name : String,
    )
      @list_of_calls_outside_required_blocks = [] of Crystal::Call
      @list_of_multitenant_model_names = Set(String).new
    end

    def self.find_multitenant_model_names(content : String, model_macro_name : String) : Set(String)
      visitor = new(
        Set(String).new,
        [] of String,
        "",
        "",
        model_macro_name,
      )
      visitor.accept(Crystal::Parser.new(content).parse)
      visitor.list_of_multitenant_model_names
    rescue Crystal::SyntaxException
      Set(String).new
    end

    def visit(node : Crystal::ASTNode) : Bool
      true
    end

    def visit(node : Crystal::ClassDef) : Bool
      @list_of_class_names << node.name.names.last
      true
    end

    def end_visit(node : Crystal::ClassDef) : Nil
      @list_of_class_names.pop
    end

    def visit(node : Crystal::Def) : Bool
      @list_of_method_scope_snapshots << {@required_block_depth, @list_of_unscoped_model_names.dup}
      @required_block_depth = 0
      @list_of_unscoped_model_names.clear
      true
    end

    def end_visit(node : Crystal::Def) : Nil
      previous_scope = @list_of_method_scope_snapshots.pop?
      return unless previous_scope

      @required_block_depth = previous_scope[0]
      @list_of_unscoped_model_names = previous_scope[1]
    end

    def visit(node : Crystal::Call) : Bool
      if node.name == @model_macro_name && !@list_of_class_names.empty?
        @list_of_multitenant_model_names << @list_of_class_names.last
      end

      if query_call_is_outside_required_blocks?(node)
        @list_of_calls_outside_required_blocks << node
      end

      true
    end

    def visit(node : Crystal::Block) : Bool
      call = node.call
      enters_required_block = call.try { |block_call| is_required_block_call?(block_call) } || false
      if enters_required_block
        @required_block_depth += 1
      end

      escape_model_name = call.try { |block_call| escaped_model_name(block_call) }
      if escape_model_name
        @list_of_unscoped_model_names << escape_model_name
      end

      @list_of_block_scope_changes << {enters_required_block, escape_model_name}
      true
    end

    def end_visit(node : Crystal::Block) : Nil
      scope_change = @list_of_block_scope_changes.pop?
      return unless scope_change

      @required_block_depth -= 1 if scope_change[0]
      if scope_change[1]
        @list_of_unscoped_model_names.pop
      end
    end

    private def query_call_is_outside_required_blocks?(call : Crystal::Call) : Bool
      return false unless @list_of_query_method_names.includes?(call.name)

      model_name = model_name_for_receiver(call.obj)
      return false unless model_name && @list_of_scoped_model_names.includes?(model_name)
      return false if @required_block_depth > 0
      return false if @list_of_unscoped_model_names.includes?(model_name)

      true
    end

    private def is_required_block_call?(call : Crystal::Call) : Bool
      return false if @required_block_call_name.empty?

      if @required_block_call_name.includes?('.')
        full_call_name(call) == @required_block_call_name
      else
        call.name == @required_block_call_name
      end
    end

    private def escaped_model_name(call : Crystal::Call) : String?
      return nil if @escape_block_call_name.empty?
      return nil unless call.name == @escape_block_call_name

      model_name = model_name_for_receiver(call.obj)
      return nil unless model_name && @list_of_scoped_model_names.includes?(model_name)

      model_name
    end

    private def model_name_for_receiver(node : Crystal::ASTNode?) : String?
      case node
      when Crystal::Path
        node.names.last?
      when Crystal::Call
        model_name_for_receiver(node.obj)
      else
        nil
      end
    end

    private def full_call_name(call : Crystal::Call) : String
      case receiver = call.obj
      when Crystal::Path
        "#{receiver.names.join("::")}.#{call.name}"
      when Crystal::Call
        "#{full_call_name(receiver)}.#{call.name}"
      else
        call.name
      end
    end
  end
end
