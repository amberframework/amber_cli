require "../core/base_command"
require "file_utils"
require "../helpers/helpers"

# The `exec` command executes Crystal code within the context of your
# Amber application, providing access to models, configuration, and environment.
#
# ## Usage
# ```
# amber exec 'Crystal code here'
# amber exec -f script.cr
# ```
#
# ## Options
# - `-f, --file` - Execute code from a file
# - `-e, --env` - Environment to run in
#
# ## Examples
# ```
# # Execute inline Crystal code
# amber exec 'puts User.count'
#
# # Run a script file
# amber exec -f scripts/data_migration.cr
#
# # Query the database in production
# amber exec -e production 'puts Post.where(published: true).count'
# ```
module AmberCLI::Commands
  class ExecCommand < AmberCLI::Core::BaseCommand
    getter code : String = ""
    getter editor : String = ENV.fetch("EDITOR", "vim")
    getter back : String = "0"
    getter filename : String
    getter filelogs : String

    def initialize(command_name : String)
      @filename = "./tmp/#{Time.utc.to_unix_ms}_console.cr"
      @filelogs = @filename.sub("console.cr", "console_result.log")
      super(command_name)
    end

    def help_description : String
      "Executes Crystal code within the application scope"
    end

    def setup_command_options
      option_parser.on("-e EDITOR", "--editor=EDITOR", "Preferred editor (vim, nano, pico, etc)") do |ed|
        @parsed_options["editor"] = ed
        @editor = ed
      end

      option_parser.on("-b TIMES", "--back=TIMES", "Runs previous command files") do |times|
        @parsed_options["back"] = times
        @back = times
      end

      option_parser.separator ""
      option_parser.separator "Usage: amber exec [CODE_OR_FILE] [options]"
      option_parser.separator ""
      option_parser.separator "Arguments:"
      option_parser.separator "  CODE_OR_FILE    Crystal code or .cr file to execute"
      option_parser.separator ""
      option_parser.separator "Examples:"
      option_parser.separator "  amber exec 'puts \"Hello World\"'"
      option_parser.separator "  amber exec my_script.cr"
      option_parser.separator "  amber exec --editor nano"
      option_parser.separator "  amber exec --back 1"
    end

    def validate_arguments
      @code = remaining_arguments.join(" ")
    end

    def execute
      exit_code = 0
      Dir.mkdir("tmp") unless Dir.exists?("tmp")

      if code.empty? || File.exists?(code)
        prepare_file
        system("#{editor} #{filename}")
      else
        File.write(filename, wrap(code))
      end

      if File.exists?(filename)
        crystal_code = [] of String
        crystal_code << %(require "./config/application.cr") if Dir.exists?("config")
        crystal_code << %(require "#{filename}")
        exit_code = execute_crystal(%(crystal eval '#{crystal_code.join("\n")}'))
      end

      unless exit_code == 0
        puts File.read(filename)
        exit!(error: true)
      end
    end

    private def prepare_file
      source_filename = if File.exists?(code)
                          code
                        elsif back.to_i(strict: false) > 0
                          Dir.glob("./tmp/*_console.cr").sort.reverse![back.to_i(strict: false) - 1]?
                        end

      if source_filename
        FileUtils.cp(source_filename, filename)
      end
    end

    private def show_output
      File.open(filelogs, "r") do |file|
        loop do
          output = file.gets_to_end
          puts output unless output.empty?
          sleep 1.millisecond
        end
      end
    end

    private def execute_crystal(crystal_command)
      file = File.open(filelogs, "w")
      spawn show_output
      process = Process.run(crystal_command, shell: true, output: file, error: file)
      sleep 1.millisecond
      process.exit_code
    end

    private def wrap(crystal_code)
      <<-CRYSTAL
      result = (
        #{crystal_code}
      )
      puts result.inspect
      CRYSTAL
    end
  end
end

# Register the command
AmberCLI::Core::CommandRegistry.register("exec", ["x"], AmberCLI::Commands::ExecCommand)
