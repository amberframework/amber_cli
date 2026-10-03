module AmberCLI::Agent
  # Resolves the same compiler order used by generated agent hooks.
  class ResolveCompilerForAgentLoop
    getter? stock_compiler : Bool = false

    def initialize(@specified_path : String?, @path_lookup : Proc(String, String?))
    end

    def perform : String?
      if specified_path = @specified_path
        return specified_path unless specified_path.empty?
      end

      ["crystal-alpha", "acrystal", "crystal"].each do |command|
        if executable = @path_lookup.call(command)
          @stock_compiler = command == "crystal"
          return executable
        end
      end

      nil
    end
  end
end
