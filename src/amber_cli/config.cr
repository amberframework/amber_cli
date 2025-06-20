require "yaml"

module Amber::CLI
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

    property database : String = "pg"
    property language : String = "slang"
    property model : String = "granite"
    property recipe : (String | Nil) = nil
    property recipe_source : (String | Nil) = nil
    property watch : WatchOptions?

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
            "crystal build ./src/#{appname}.cr -o bin/#{appname}",
          ],
          "run_commands" => [
            "bin/#{appname}",
          ],
          "include" => [
            "./config/**/*.cr",
            "./src/**/*.cr",
            "./src/views/**/*.slang",
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
