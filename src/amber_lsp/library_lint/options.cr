module AmberLSP::LibraryLint
  # Holds parsed arguments for the library lint command.
  struct Options
    getter root_path : String
    getter since_reference : String
    getter format : String
    getter list_of_paths : Array(String)
    getter list_of_carried_in_paths : Array(String)
    getter? all = false
    getter? advisory = false
    getter? has_explicit_paths = false

    # Initializes the command options.
    def initialize(
      @root_path : String,
      @since_reference : String,
      @format : String,
      @list_of_paths : Array(String),
      @list_of_carried_in_paths : Array(String),
      @all : Bool,
      @advisory : Bool,
      @has_explicit_paths : Bool,
    )
    end
  end
end
