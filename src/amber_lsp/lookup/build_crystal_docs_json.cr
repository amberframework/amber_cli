require "process"

require "./index_cache"

module AmberLSP::Lookup
  class BuildCrystalDocsJSON
    def initialize(
      @compiler_path : String,
      @working_directory : String,
      @list_of_entrypoints : Array(String),
      @project_name : String,
      @project_version : String,
      @docs_flags : Array(String),
      @environment_overrides : Hash(String, String) = {} of String => String,
    )
    end

    def perform : String
      output = IO::Memory.new
      error_output = IO::Memory.new
      arguments = [
        "docs",
        "--format=json",
        "--project-name=#{@project_name}",
        "--project-version=#{@project_version}",
      ]
      @docs_flags.each do |flag|
        arguments << "-D"
        arguments << flag
      end
      arguments.concat(@list_of_entrypoints)

      begin
        status = Process.run(
          @compiler_path,
          arguments,
          chdir: @working_directory,
          env: @environment_overrides,
          output: output,
          error: error_output,
        )
      rescue ex : IO::Error
        raise APIIndexBuildError.new("Could not run crystal-alpha docs: #{ex.message}")
      end

      unless status.success?
        error_message = error_output.to_s.strip
        raise APIIndexBuildError.new("crystal-alpha docs failed for #{@project_name}: #{error_message}")
      end

      output.to_s
    end
  end
end
