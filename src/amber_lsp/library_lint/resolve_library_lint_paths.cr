module AmberLSP::LibraryLint
  # Resolves command paths to sorted, root-relative Crystal source paths.
  class ResolveLibraryLintPaths
    # Initializes the resolver with the project root and requested paths.
    def initialize(
      @root_path : String,
      @list_of_requested_paths : Array(String),
      @has_explicit_paths : Bool,
    )
    end

    # Resolves all Crystal files selected by *list_of_requested_paths*.
    def perform : AmberLSP::Rules::Library::Support::ListOfStrings
      list_of_absolute_paths = [] of String
      @list_of_requested_paths.each do |requested_path|
        collect_paths_for(requested_path, list_of_absolute_paths)
      end

      list_of_relative_paths = list_of_absolute_paths.map do |absolute_path|
        relative_path_for(absolute_path)
      end
      list_of_relative_paths.uniq!
      list_of_relative_paths.sort!
      list_of_relative_paths
    end

    private def collect_paths_for(requested_path : String, list_of_absolute_paths : Array(String)) : Nil
      absolute_pattern = File.expand_path(requested_path, @root_path)
      has_glob = requested_path.includes?('*') || requested_path.includes?('?') || requested_path.includes?('[')

      if has_glob
        matches = Dir.glob(absolute_pattern)
        raise InvalidArguments.new("Path did not match any files: #{requested_path}") if matches.empty?
        matches.each { |match| collect_path_match(match, list_of_absolute_paths) }
      else
        collect_path_match(absolute_pattern, list_of_absolute_paths)
      end
    end

    private def collect_path_match(path : String, list_of_absolute_paths : Array(String)) : Nil
      if File.file?(path)
        unless path.ends_with?(".cr")
          raise InvalidArguments.new("Path must identify Crystal files: #{path}")
        end
        list_of_absolute_paths << File.expand_path(path)
      elsif File.directory?(path)
        crystal_pattern = File.join(path, "**", "*.cr")
        list_of_absolute_paths.concat(Dir.glob(crystal_pattern).map { |source_path| File.expand_path(source_path) })
      else
        raise InvalidArguments.new("Path does not exist: #{path}") if @has_explicit_paths
      end
    end

    private def relative_path_for(absolute_path : String) : String
      root_prefix = @root_path.ends_with?(File::SEPARATOR.to_s) ? @root_path : "#{@root_path}#{File::SEPARATOR}"
      unless absolute_path.starts_with?(root_prefix)
        raise InvalidArguments.new("Path must be inside the project root: #{absolute_path}")
      end

      absolute_path[root_prefix.size..]
    end
  end
end
