require "yaml"

module AmberLSP::LibraryLint
  # Runs the isolated library lint command for a project.
  class RunLibraryLintCheck
    # Initializes the command with arguments and output streams.
    def initialize(
      @list_of_arguments : Array(String),
      @output : IO = STDOUT,
      @error_output : IO = STDERR,
    )
    end

    # Runs the check command and returns its process status.
    def perform : Int32
      if @list_of_arguments.includes?("--help") || @list_of_arguments.includes?("-h")
        @output.puts(ParseLibraryLintCheckOptions::USAGE)
        return 0
      end

      options = ParseLibraryLintCheckOptions.new(@list_of_arguments).perform
      root_path = File.expand_path(options.root_path)
      unless File.directory?(root_path)
        raise InvalidArguments.new("Project root does not exist: #{root_path}")
      end

      configuration = AmberLSP::Configuration.load(root_path)
      list_of_exclusion_patterns = ReadLibraryLintExclusionPatterns.new(
        root_path,
        configuration.exclude_patterns,
      ).perform
      list_of_relative_paths = ResolveLibraryLintPaths.new(
        root_path,
        options.list_of_paths,
        options.has_explicit_paths?,
      ).perform
      list_of_carried_in_prefixes = normalize_carried_in_paths(root_path, options.list_of_carried_in_paths)
      changed_lines = changed_lines_for(root_path, options)
      list_of_issues = CheckLibraryProjectFiles.new(
        root_path,
        list_of_relative_paths,
        configuration,
        list_of_exclusion_patterns,
        list_of_carried_in_prefixes,
        changed_lines,
      ).perform
      report = Report.new(list_of_issues)
      PrintLibraryLintReport.new(report, options.format, @output).perform
      report.exit_code(options.advisory?)
    rescue ex : InvalidArguments
      @error_output.puts(ex.message || "Invalid check arguments")
      2
    rescue ex : AmberLSP::Rules::Library::Support::GitCommandError
      @error_output.puts(ex.message || "Git command failed")
      2
    rescue ex : YAML::ParseException
      @error_output.puts("amber-lsp check: invalid .amber-lsp.yml: #{ex.message}")
      2
    rescue ex : IO::Error
      @error_output.puts("amber-lsp check: #{ex.message || "project files could not be read"}")
      2
    end

    private def changed_lines_for(
      root_path : String,
      options : Options,
    ) : AmberLSP::Rules::Library::Support::GitChangedLines?
      return if options.all?

      AmberLSP::Rules::Library::Support::GitChangedLines.new(root_path, options.since_reference).perform
    end

    private def normalize_carried_in_paths(
      root_path : String,
      list_of_paths : Array(String),
    ) : Array(String)
      list_of_paths.map do |carried_in_path|
        absolute_path = File.expand_path(carried_in_path, root_path)
        unless File.file?(absolute_path) || File.directory?(absolute_path)
          raise InvalidArguments.new("Carried-in path does not exist: #{carried_in_path}")
        end

        next "" if absolute_path == root_path

        root_prefix = root_path.ends_with?(File::SEPARATOR.to_s) ? root_path : "#{root_path}#{File::SEPARATOR}"
        unless absolute_path.starts_with?(root_prefix)
          raise InvalidArguments.new("Carried-in path must be inside the project root: #{carried_in_path}")
        end

        absolute_path[root_prefix.size..].rstrip('/')
      end
    end
  end
end
