require "compiler/crystal/syntax"

module AmberLSP::Rules::Library::Support
  # Parses Crystal source and returns nil when its syntax is incomplete.
  class ParseCrystalSource
    def initialize(@content : String)
    end

    # Parses *content* as a Crystal syntax tree.
    def perform : Crystal::ASTNode?
      Crystal::Parser.new(@content).parse
    rescue Crystal::SyntaxException
      nil
    end
  end
end
