require "./coverage"

module AmberLSP
  # When a Crystal file, its project root, and optional current analysis state
  # are provided, then return diagnostics with an explicit coverage outcome.
  class AnalyzeFileWithCoverage
    getter analysis_analyzer : Analyzer?

    def initialize(
      @file_path : String,
      @content : String? = nil,
      @project_root_path : String? = nil,
      @configured_analyzer : Analyzer? = nil,
    )
      @analysis_analyzer = @configured_analyzer
    end

    def perform : Coverage::Result
      current_content = document_content
      current_project_context = detect_project_context
      if error = current_project_context.failure_reason
        return Coverage::Failed.new(error)
      end

      unless current_project_context.stack_project?
        return Coverage::Declined.new("project is not an Amber V2 stack project")
      end

      analyzer = analyzer_for(current_project_context)
      @analysis_analyzer = analyzer
      if error = analyzer.rule_pack_load_failure
        return Coverage::Failed.new(error)
      end
      Coverage::Covered.new(analyzer.analyze(@file_path, current_content))
    rescue ex : Exception
      Coverage::Failed.new("#{ex.class}: #{ex.message}")
    end

    private def detect_project_context : ProjectContext
      if root_path = @project_root_path
        ProjectContext.detect(root_path)
      else
        ProjectContext.detect_for_file(@file_path)
      end
    end

    private def analyzer_for(project_context : ProjectContext) : Analyzer
      if analyzer = @configured_analyzer
        return analyzer
      end

      analyzer = Analyzer.new
      analyzer.configure(project_context)
      analyzer
    end

    private def document_content : String
      if content = @content
        return content
      end

      File.read(@file_path)
    end
  end
end
