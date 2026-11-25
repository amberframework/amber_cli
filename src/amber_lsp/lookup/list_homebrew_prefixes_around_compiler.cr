module AmberLSP::Lookup
  # Lists the Homebrew prefix that holds a compiler, from the compiler's path
  # as found on PATH and from its symlink-resolved path. A compiler belongs to
  # a Homebrew prefix when it sits at one of these places:
  #
  # - `<prefix>/Cellar/<formula>/<version>/bin/<compiler>`
  # - `<prefix>/opt/<formula>/bin/<compiler>`
  # - `<prefix>/bin/<compiler>`
  #
  # and `<prefix>/Cellar` exists. Any other location has no prefix, so nothing
  # above an arbitrary compiler (a project folder, a home folder) is searched.
  class ListHomebrewPrefixesAroundCompiler
    def initialize(@compiler_path : String)
    end

    def perform : Array(String)
      list_of_compiler_paths = [@compiler_path]
      if resolved_compiler_path = resolve_compiler_symlinks
        list_of_compiler_paths << resolved_compiler_path
      end

      list_of_homebrew_prefixes = [] of String
      list_of_compiler_paths.each do |compiler_path|
        if homebrew_prefix = homebrew_prefix_holding(Path[compiler_path])
          list_of_homebrew_prefixes << homebrew_prefix
        end
      end
      list_of_homebrew_prefixes.uniq
    end

    private def resolve_compiler_symlinks : String?
      File.realpath(@compiler_path)
    rescue File::Error
      nil
    end

    private def homebrew_prefix_holding(compiler_path : Path) : String?
      bin_directory = compiler_path.parent
      return nil unless bin_directory.basename == "bin"

      directory_above_bin = bin_directory.parent
      directory_two_levels_above_bin = directory_above_bin.parent
      prefix_candidate =
        if directory_two_levels_above_bin.parent.basename == "Cellar"
          directory_two_levels_above_bin.parent.parent
        elsif directory_two_levels_above_bin.basename == "opt"
          directory_two_levels_above_bin.parent
        else
          directory_above_bin
        end

      return nil if prefix_candidate == prefix_candidate.root
      return nil unless Dir.exists?(prefix_candidate.join("Cellar"))

      prefix_candidate.to_s
    end
  end
end
