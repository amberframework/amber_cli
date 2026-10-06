module AmberLSP
  class CheckFileForDiagnostics
    def initialize(@file_path : String, @output : IO = STDOUT, _error : IO = STDERR)
    end

    def perform : Int32
      file_path = File.expand_path(@file_path)
      analysis = AnalyzeFileWithCoverage.new(file_path).perform

      if analysis.is_a?(Coverage::Covered)
        return print_covered_result(analysis, file_path)
      end

      if analysis.is_a?(Coverage::Declined)
        @output.puts "amber-lsp: declined #{analysis.reason}"
      elsif analysis.is_a?(Coverage::Failed)
        @output.puts "amber-lsp: failed #{analysis.error}"
      end

      2
    end

    private def print_covered_result(covered : Coverage::Covered, file_path : String) : Int32
      list_of_diagnostics = covered.list_of_diagnostics
      error_count = list_of_diagnostics.count { |diagnostic| diagnostic.severity == Rules::Severity::Error }
      @output.puts covered_status_line(list_of_diagnostics.size, error_count)

      list_of_diagnostics.each do |diagnostic|
        line = diagnostic.range.start.line + 1
        @output.puts "#{file_path}:#{line}: #{diagnostic.severity.to_s.downcase}: #{diagnostic.code}: #{diagnostic.message}"
      end

      error_count.zero? ? 0 : 1
    end

    private def covered_status_line(diagnostic_count : Int32, error_count : Int32) : String
      return "amber-lsp: covered no diagnostics" if diagnostic_count.zero?

      diagnostic_word = diagnostic_count == 1 ? "diagnostic" : "diagnostics"
      error_word = error_count == 1 ? "error" : "errors"
      "amber-lsp: covered #{diagnostic_count} #{diagnostic_word}, #{error_count} #{error_word}"
    end
  end
end
