module AmberLSP::Lookup
  class ResolveAPIIndexDocsEntries
    def initialize(
      @root_path : String,
      @library_name : String,
      @list_of_overrides : Array(String)? = nil,
    )
    end

    def perform : Array(String)
      root_path = File.expand_path(@root_path)
      if list_of_overrides = @list_of_overrides
        return normalize_overrides(root_path, list_of_overrides)
      end

      source_root = File.join(root_path, "src")
      list_of_entries = Dir.glob(File.join(source_root, "*.cr")).sort
      if list_of_entries.empty?
        list_of_entries = Dir.glob(File.join(source_root, "**", "*.cr")).sort
      end
      raise APIIndexBuildError.new("No Crystal entrypoint found under #{source_root}") if list_of_entries.empty?

      conventional_entry = File.join(source_root, "#{@library_name.gsub('-', '_')}.cr")
      main_entry = list_of_entries.includes?(conventional_entry) ? conventional_entry : list_of_entries.first
      ([main_entry] + list_of_entries.reject { |entry| entry == main_entry })
        .map { |entry| entry.sub(root_path + "/", "") }
    end

    private def normalize_overrides(root_path : String, list_of_overrides : Array(String)) : Array(String)
      raise APIIndexBuildError.new("docs_entries must contain at least one entry") if list_of_overrides.empty?

      list_of_entries = list_of_overrides.map do |entry|
        path = Path[entry]
        raise APIIndexBuildError.new("docs_entries paths must be relative to the shard root") if entry.empty? || path.absolute?
        raise APIIndexBuildError.new("docs_entries paths cannot traverse outside the shard root") if entry.split(/[\\\/]/).includes?("..")

        expanded_path = File.expand_path(entry, root_path)
        unless expanded_path.starts_with?(root_path + "/") && File.file?(expanded_path)
          raise APIIndexBuildError.new("docs entry #{entry.inspect} does not exist under #{root_path}")
        end

        entry
      end

      conventional_entry = File.join("src", "#{@library_name.gsub('-', '_')}.cr")
      if list_of_entries.includes?(conventional_entry)
        return [conventional_entry] + list_of_entries.reject { |entry| entry == conventional_entry }
      end

      list_of_entries
    end
  end
end
