require "json"

module AmberLSP::LibraryLint
  # Holds one machine-readable library lint finding.
  struct Issue
    include JSON::Serializable

    getter path : String
    getter line : Int32
    getter column : Int32
    getter classification : String
    getter rule : String
    getter message : String

    # Initializes a finding with its path, location, classification, and message.
    def initialize(
      @path : String,
      @line : Int32,
      @column : Int32,
      @classification : String,
      @rule : String,
      @message : String,
    )
    end

    # Returns whether this finding blocks the check command.
    def blocking? : Bool
      classification == "blocking"
    end
  end
end
