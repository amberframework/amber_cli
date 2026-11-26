module AmberCLI::Agent
  # Resolves the compiler order the generated agent hook uses, the one order
  # every Amber tool shares: the command in CRYSTAL when it is set, otherwise
  # `crystal-alpha`, otherwise stock `crystal`.
  class ResolveCompilerForAgentLoop
    getter? stock_compiler : Bool = false

    def initialize(@specified_command : String?, @path_lookup : Proc(String, String?))
    end

    def perform : String?
      if specified_command = @specified_command
        stripped_command = specified_command.strip
        return stripped_command unless stripped_command.empty?
      end

      ["crystal-alpha", "crystal"].each do |command|
        if executable = @path_lookup.call(command)
          @stock_compiler = command == "crystal"
          return executable
        end
      end

      nil
    end
  end
end
