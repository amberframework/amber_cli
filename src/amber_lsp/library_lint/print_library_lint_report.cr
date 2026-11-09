module AmberLSP::LibraryLint
  # Prints the text, JSON, or GitHub representation of a report.
  class PrintLibraryLintReport
    # Initializes the printer with *report*, *format*, and output stream.
    def initialize(
      @report : Report,
      @format : String,
      @output : IO,
    )
    end

    # Prints all findings and the final counts line.
    def perform : Nil
      case @format
      when "json"
        @output.puts(@report.to_json)
        return
      when "github"
        print_github_findings
      else
        print_text_findings
      end
      print_counts
    end

    private def print_text_findings : Nil
      @report.list_of_issues.each do |issue|
        @output.puts("#{issue.path}:#{issue.line}:#{issue.column} [#{issue.classification}] #{issue.rule}: #{issue.message}")
      end
    end

    private def print_github_findings : Nil
      @report.list_of_issues.each do |issue|
        message = issue.message.gsub('\n', " ").gsub('\r', " ")
        @output.puts("::warning file=#{issue.path},line=#{issue.line},col=#{issue.column},title=#{issue.rule}::#{message}")
      end
    end

    private def print_counts : Nil
      issue_count = @report.list_of_issues.size
      issue_label = issue_count == 1 ? "issue" : "issues"
      @output.puts("#{issue_count} #{issue_label} (#{@report.blocking_count} blocking, #{@report.advisory_count} advisory)")
    end
  end
end
