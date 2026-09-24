require "log"
require "yaml"

module AmberLSP::LibraryRulePacks
  class PrintDetectedRulePackContexts
    Log = ::Log.for(self)

    def initialize(@list_of_arguments : Array(String))
    end

    def perform : Int32
      project_context = AmberLSP::ProjectContext.detect(project_root_from_arguments)
      list_of_rule_packs = LoadRulePacksForProject.new(project_context).load_rule_packs
      list_of_output_lines = [] of String

      list_of_rule_packs.each do |rule_pack|
        next if project_context.shard_name == rule_pack.library_shard_name

        project_state = DetermineProjectRulePackState.new(project_context, rule_pack, "", "")
        next unless project_state.has_any_applicable_mode?

        append_detected_mode_contexts(list_of_output_lines, rule_pack, project_state)
      end

      STDOUT.puts(list_of_output_lines.join('\n')) unless list_of_output_lines.empty?
      0
    rescue ex : ArgumentError | YAML::ParseException | IO::Error
      Log.error(exception: ex) do
        "amber-lsp context failed: #{ex.class}: #{ex.message}"
      end
      1
    end

    private def project_root_from_arguments : String
      project_root = Dir.current
      arguments = @list_of_arguments.dup

      until arguments.empty?
        argument = arguments.shift
        case argument
        when "--root"
          root_argument = arguments.shift?
          raise ArgumentError.new("--root requires a directory") unless root_argument
          project_root = File.expand_path(root_argument)
        else
          raise ArgumentError.new("unexpected argument #{argument.inspect}")
        end
      end

      find_project_root(project_root)
    end

    private def find_project_root(start_path : String) : String
      current_path = File.expand_path(start_path)
      current_path = File.dirname(current_path) unless File.directory?(current_path)

      loop do
        return current_path if File.file?(File.join(current_path, "shard.yml"))

        parent_path = File.dirname(current_path)
        return current_path if parent_path == current_path
        current_path = parent_path
      end
    end

    private def append_detected_mode_contexts(
      list_of_output_lines : Array(String),
      rule_pack : DescribeLibraryRulePack,
      project_state : DetermineProjectRulePackState,
    ) : Nil
      rule_pack.modes_by_name.each do |mode_name, mode|
        next unless project_state.mode_detected?(mode_name)
        next if mode.guidance_text.strip.empty?

        list_of_output_lines << "#{rule_pack.pack_id} (#{mode_name})"
        list_of_output_lines.concat(mode.guidance_text.lines.map(&.rstrip))
      end
    end
  end
end
