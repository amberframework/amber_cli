module Amber::CLI
  # Names the compiler that commands shelling out to Crystal run: the command
  # in the CRYSTAL environment variable when it is set, otherwise `crystal`,
  # otherwise `crystal-alpha` when `crystal` is not on PATH (a Homebrew install
  # of agent-crystal ships only `crystal-alpha`).
  class ResolveCrystalCompilerCommand
    def initialize(@specified_command : String?, @path_lookup : Proc(String, String?))
    end

    def perform : String
      if specified_command = @specified_command
        return specified_command unless specified_command.strip.empty?
      end

      return "crystal" if @path_lookup.call("crystal")

      "crystal-alpha"
    end
  end

  def self.crystal_compiler_command : String
    ResolveCrystalCompilerCommand.new(
      ENV["CRYSTAL"]?,
      ->(command : String) { Process.find_executable(command) },
    ).perform
  end
end
