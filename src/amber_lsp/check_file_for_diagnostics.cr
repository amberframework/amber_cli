module AmberLSP
  class CheckFileForDiagnostics
    def initialize(@file_path : String, @output : IO = STDOUT, @error : IO = STDERR)
    end

    def perform : Int32
      path = File.expand_path(@file_path)
      unless File.file?(path)
        @error.puts "amber-lsp: file not found: #{path}"
        return 2
      end

      analyzer = Analyzer.new
      analyzer.configure(ProjectContext.detect(Dir.current))
      diagnostics = analyzer.analyze(path, File.read(path))
      diagnostics.each do |diagnostic|
        line = diagnostic.range.start.line + 1
        @output.puts "#{path}:#{line}: #{diagnostic.severity.to_s.downcase}: #{diagnostic.code}: #{diagnostic.message}"
      end
      diagnostics.any? { |diagnostic| diagnostic.severity == Rules::Severity::Error } ? 1 : 0
    rescue ex : File::Error | YAML::ParseException
      @error.puts "amber-lsp: #{ex.message}"
      2
    end
  end
end
