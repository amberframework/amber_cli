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
      list_of_prefix_candidates = [] of Path
      if directory_two_levels_above_bin.parent.basename == "Cellar"
        list_of_prefix_candidates << directory_two_levels_above_bin.parent.parent
      end
      if directory_two_levels_above_bin.basename == "opt"
        list_of_prefix_candidates << directory_two_levels_above_bin.parent
      end
      list_of_prefix_candidates << directory_above_bin

      homebrew_prefix = list_of_prefix_candidates.find { |prefix_candidate| holds_a_cellar?(prefix_candidate) }
      homebrew_prefix.try(&.to_s)
    end

    private def holds_a_cellar?(prefix_candidate : Path) : Bool
      return false if prefix_candidate == prefix_candidate.root

      Dir.exists?(prefix_candidate.join("Cellar"))
    end
  end
end
