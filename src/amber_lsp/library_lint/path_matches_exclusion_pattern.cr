module AmberLSP::LibraryLint
  # Checks whether a project-relative path matches a configured exclusion.
  class PathMatchesExclusionPattern
    # Initializes the matcher with *relative_path* and *pattern*.
    def initialize(@relative_path : String, @pattern : String)
    end

    # Returns whether *relative_path* is covered by *pattern*.
    def perform? : Bool
      normalized_pattern = @pattern.lchop("./")
      if normalized_pattern.ends_with?("/")
        directory_prefix = normalized_pattern.rstrip('/')
        return @relative_path == directory_prefix || @relative_path.starts_with?("#{directory_prefix}/")
      end

      return true if File.match?(normalized_pattern, @relative_path)
      return @relative_path.includes?(normalized_pattern) unless has_glob?(normalized_pattern)

      false
    end

    private def has_glob?(pattern : String) : Bool
      pattern.includes?('*') || pattern.includes?('?') || pattern.includes?('[')
    end
  end
end
