module AmberLSP::Coverage
  # :nodoc:
  struct Failed
    getter error : String

    def initialize(@error : String)
    end
  end
end
