module AmberLSP
  class DocumentStore
    def initialize
      @documents = Hash(String, String).new
    end

    def update(uri : String, content : String) : Nil
      @documents[uri] = content
    end

    def get(uri : String) : String?
      @documents[uri]?
    end

    def remove(uri : String) : Nil
      @documents.delete(uri)
    end

    def has?(uri : String) : Bool
      @documents.has_key?(uri)
    end
  end
end
