require "./list_homebrew_prefixes_around_compiler"

module AmberLSP::Lookup
  # Finds an llvm-config that reports the same LLVM major.minor the compiler
  # was built with. Homebrew's llvm@N and llvm are keg-only, so they are searched first in
  # the Homebrew prefix that holds the compiler (this covers Linuxbrew and
  # custom prefixes), then in the standard Homebrew prefixes, then on PATH.
  class FindLLVMConfigForCompiler
    DEFAULT_LIST_OF_STANDARD_HOMEBREW_PREFIXES = ["/opt/homebrew", "/usr/local"]

    def initialize(
      @compiler_path : String,
      @compiler_llvm_version : String,
      @list_of_standard_homebrew_prefixes : Array(String) = DEFAULT_LIST_OF_STANDARD_HOMEBREW_PREFIXES,
      @path_lookup : Proc(String, String?) = ->(command : String) { Process.find_executable(command) },
    )
    end

    # True when `llvm-config --version` output names exactly `major.minor`,
    # so 21.1.8 matches 21.1 and 21.10.2 does not.
    def self.reports_llvm_version?(version_output : String, major : String, minor : String) : Bool
      list_of_version_components = version_output.strip.split('.')
      list_of_version_components[0]? == major && list_of_version_components[1]? == minor
    end

    def perform : String?
      list_of_version_parts = @compiler_llvm_version.split('.')
      major = list_of_version_parts[0]?
      minor = list_of_version_parts[1]?
      return nil unless major && minor

      list_of_candidates_in_search_order(major, minor).each do |candidate|
        return candidate if candidate_reports_llvm_version?(candidate, major, minor)
      end

      nil
    end

    private def list_of_candidates_in_search_order(major : String, minor : String) : Array(String)
      list_of_homebrew_prefixes = ListHomebrewPrefixesAroundCompiler.new(@compiler_path).perform
      list_of_homebrew_prefixes.concat(@list_of_standard_homebrew_prefixes)

      # The versioned keg first, then the unversioned `llvm` formula's keg; the
      # version check below rejects either one when its LLVM does not match.
      list_of_candidates = list_of_homebrew_prefixes.flat_map do |homebrew_prefix|
        [
          File.join(homebrew_prefix, "opt", "llvm@#{major}", "bin", "llvm-config"),
          File.join(homebrew_prefix, "opt", "llvm", "bin", "llvm-config"),
        ]
      end
      ["llvm-config-#{major}.#{minor}", "llvm-config-#{major}", "llvm-config"].each do |command|
        if executable = @path_lookup.call(command)
          list_of_candidates << executable
        end
      end
      list_of_candidates.uniq
    end

    private def candidate_reports_llvm_version?(candidate : String, major : String, minor : String) : Bool
      return false unless File.file?(candidate) && File::Info.executable?(candidate)

      version_output = IO::Memory.new
      status = Process.run(candidate, ["--version"], output: version_output, error: Process::Redirect::Close)
      status.success? && self.class.reports_llvm_version?(version_output.to_s, major, minor)
    rescue IO::Error
      false
    end
  end
end
