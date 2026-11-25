module Amber::CLI
  # Names the compiler that commands shelling out to Crystal run, in the one
  # order every Amber tool uses: the command in the CRYSTAL environment
  # variable when it is set, otherwise `crystal-alpha` when it is on PATH,
  # otherwise `crystal`.
  class ResolveCrystalCompilerCommand
    def initialize(@specified_command : String?, @path_lookup : Proc(String, String?))
    end

    def perform : String
      if specified_command = @specified_command
        stripped_command = specified_command.strip
        return stripped_command unless stripped_command.empty?
      end

      return "crystal-alpha" if @path_lookup.call("crystal-alpha")

      "crystal"
    end
  end

  def self.crystal_compiler_command : String
    ResolveCrystalCompilerCommand.new(
      ENV["CRYSTAL"]?,
      ->(command : String) { Process.find_executable(command) },
    ).perform
  end
end
