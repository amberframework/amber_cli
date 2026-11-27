# :nodoc:
require "yaml"
require "./helpers/resolve_crystal_compiler_command"

module Amber::CLI
  AMBER_YML = ".amber.yml" # TODO: move to config/amber.yml

  def self.config
    if File.exists? AMBER_YML
      begin
        Config.from_yaml File.read(AMBER_YML)
      rescue ex : YAML::ParseException
        Log.error(exception: ex) { "Couldn't parse #{AMBER_YML} file" }
        exit 1
      end
    else
      Config.new
    end
  end

  class Config
    include YAML::Serializable

    SHARD_YML    = "shard.yml"
    DEFAULT_NAME = "[process_name]"

    # see defaults below
    alias WatchOptions = Hash(String, Hash(String, Array(String)))

    # The `build:` section of .amber.yml, read by `amber build`:
    #
    # ```yaml
    # build:
    #   target_tier: x86-64-v3
    # ```
    class BuildOptions
      include YAML::Serializable

      property target_tier : String? = nil

      def initialize
      end
    end

    property database : String = "sqlite"
    property language : String = "ecr"
    property model : String = "grant"
    property watch : WatchOptions?
    property build : BuildOptions = BuildOptions.new

    def initialize
      @watch = default_watch_options
    end

    def watch : WatchOptions
      @watch ||= default_watch_options
    end

    def default_watch_options
      appname = self.class.get_name
      WatchOptions{
        "run" => Hash{
          "build_commands" => [
            "mkdir -p bin",
            "#{Process.quote(Amber::CLI.crystal_compiler_command)} build ./src/#{appname}.cr -o bin/#{appname}",
          ],
          "run_commands" => [
            "bin/#{appname}",
          ],
          "include" => [
            "./config/**/*.cr",
            "./src/**/*.cr",
            "./src/views/**/*.ecr",
          ],
        },
      }
    end

    def self.get_name
      if File.exists?(SHARD_YML) &&
         (yaml = YAML.parse(File.read SHARD_YML)) &&
         (name = yaml["name"]?)
        name.as_s
      else
        DEFAULT_NAME
      end
    end
  end
end
