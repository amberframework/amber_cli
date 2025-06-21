require "../core/base_command"
require "../helpers/process_runner"

module AmberCLI::Commands
  class WatchCommand < AmberCLI::Core::BaseCommand
    getter name : String = ""
    getter build_command : String = ""
    getter run_command : String = ""
    getter watch_files : Array(String) = [] of String
    getter show_info : Bool = false

    def help_description : String
      "Starts Amber development server and rebuilds on file changes"
    end

    def setup_command_options
      option_parser.on("-n NAME", "--name=NAME", "Sets the name of the app process") do |app_name|
        @parsed_options["name"] = app_name
        @name = app_name
      end

      option_parser.on("-b BUILD", "--build=BUILD", "Overrides the default build command") do |build|
        @parsed_options["build"] = build
        @build_command = build
      end

      option_parser.on("-r RUN", "--run=RUN", "Overrides the default run command") do |run|
        @parsed_options["run"] = run
        @run_command = run
      end

      option_parser.on("-w FILES", "--watch=FILES", "Overrides default files to watch (comma-separated)") do |files|
        @parsed_options["watch"] = files
        @watch_files = files.split(",").map(&.strip)
      end

      option_parser.on("-i", "--info", "Shows the values for build/run commands, and watched files") do
        @parsed_options["info"] = true
        @show_info = true
      end

      option_parser.separator ""
      option_parser.separator "Usage: amber watch [options]"
      option_parser.separator ""
      option_parser.separator "Examples:"
      option_parser.separator "  amber watch"
      option_parser.separator "  amber watch --name my_app"
      option_parser.separator "  amber watch --info"
      option_parser.separator "  amber watch --build 'crystal build src/my_app.cr' --run './my_app'"
    end

    def execute
      # Load defaults from config if available
      load_defaults

      if show_info
        print_info
        return
      end

      info "Starting watch mode..."
      start_watch_process
    end

    private def load_defaults
      # Set defaults if not provided
      if @name.empty?
        @name = get_app_name
      end

      if @build_command.empty?
        @build_command = get_default_build_command
      end

      if @run_command.empty?
        @run_command = get_default_run_command
      end

      if @watch_files.empty?
        @watch_files = get_default_watch_files
      end
    end

    private def get_app_name
      if File.exists?(".amber.yml")
        content = File.read(".amber.yml")
        if match = content.match(/app:\s*(.+)/)
          return match[1].strip
        end
      end
      
      if File.exists?("shard.yml")
        content = File.read("shard.yml")
        if match = content.match(/name:\s*(.+)/)
          return match[1].strip
        end
      end
      
      File.basename(Dir.current)
    end

    private def get_default_build_command
      "crystal build src/#{@name}.cr -o bin/#{@name}"
    end

    private def get_default_run_command
      "./bin/#{@name}"
    end

    private def get_default_watch_files
      [
        "src/**/*.cr",
        "config/**/*.cr", 
        "config/**/*.yml",
        "config/**/*.yaml"
      ]
    end

    private def print_info
      puts <<-INFO
      Watch Configuration:
        name:       #{@name}
        build:      #{@build_command}
        run:        #{@run_command}
        files:      #{@watch_files.join(", ")}
      INFO
    end

    private def start_watch_process
      build_commands = {"run" => @build_command}
      run_commands = {"run" => @run_command}
      includes = {"run" => @watch_files}
      excludes = Hash(String, Array(String)).new

      process_runner = Sentry::ProcessRunner.new(
        process_name: @name,
        build_commands: build_commands,
        run_commands: run_commands,
        includes: includes,
        excludes: excludes
      )

      info "Watching files: #{@watch_files.join(", ")}"
      info "Build command: #{@build_command}"
      info "Run command: #{@run_command}"
      info "Press Ctrl+C to stop"

      # Handle interrupt signal
      Signal::INT.trap do
        puts "\nStopping watch process..."
        exit(0)
      end

      process_runner.run
    end
  end
end

# Register the command
AmberCLI::Core::CommandRegistry.register("watch", ["w"], AmberCLI::Commands::WatchCommand)
