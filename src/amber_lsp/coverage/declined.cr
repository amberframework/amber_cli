module AmberLSP::Coverage
  # :nodoc:
  struct Declined
    getter reason : String

    def initialize(@reason : String)
    end
  end
end
