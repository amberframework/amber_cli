module AmberLSP::Coverage
  # :nodoc:
  struct Covered
    getter list_of_diagnostics : Array(AmberLSP::Rules::Diagnostic)

    def initialize(@list_of_diagnostics : Array(AmberLSP::Rules::Diagnostic))
    end
  end
end
