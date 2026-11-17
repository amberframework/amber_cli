module AmberLSP::Rules::Library::Support
  # Creates a diagnostic at a Crystal AST node's source location.
  class CreateDiagnosticForASTNode
    # Initializes the diagnostic builder with its AST node and message details.
    def initialize(
      @node : Crystal::ASTNode,
      @content : String,
      @rule_id : String,
      @severity : AmberLSP::Rules::Severity,
      @message : String,
      @source : String = "amber-lsp",
    )
    end

    # Creates a diagnostic or returns nil when the node has no source location.
    def perform : AmberLSP::Rules::Diagnostic?
      return unless location = @node.location

      line_index = location.line_number - 1
      start_character = location.column_number - 1
      end_character = start_character + 1
      if source_line = @content.lines[line_index]?
        line_length = source_line.size.to_i32
        end_character = line_length if end_character > line_length
      end

      range = AmberLSP::Rules::TextRange.new(
        AmberLSP::Rules::Position.new(line_index.to_i32, start_character.to_i32),
        AmberLSP::Rules::Position.new(line_index.to_i32, end_character.to_i32),
      )
      AmberLSP::Rules::Diagnostic.new(range, @severity, @rule_id, @message, @source)
    end
  end
end
