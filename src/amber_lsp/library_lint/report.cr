require "json"

module AmberLSP::LibraryLint
  alias ListOfIssues = Array(Issue)

  # Holds sorted findings and their severity counts.
  struct Report
    include JSON::Serializable

    @[JSON::Field(key: "issues")]
    getter list_of_issues : Array(Issue)
    getter blocking_count : Int32
    getter advisory_count : Int32

    # Initializes the report and calculates its blocking and advisory counts.
    def initialize(@list_of_issues : Array(Issue))
      @blocking_count = list_of_issues.count(&.blocking?)
      @advisory_count = list_of_issues.size - blocking_count
    end

    # Returns the command exit status for the selected advisory mode.
    def exit_code(advisory_mode : Bool) : Int32
      return 0 if advisory_mode || blocking_count.zero?

      1
    end
  end
end
