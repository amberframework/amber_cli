require "yaml"

module AmberLSP
  class ProjectContext
    getter root_path : String
    getter? amber_project : Bool

    def initialize(@root_path : String, @amber_project : Bool = false)
    end

    def self.detect(root_path : String) : ProjectContext
      shard_path = File.join(root_path, "shard.yml")

      unless File.exists?(shard_path)
        return ProjectContext.new(root_path, amber_project: false)
      end

      content = File.read(shard_path)
      is_amber = has_amber_dependency?(content)

      ProjectContext.new(root_path, amber_project: is_amber)
    end

    private def self.has_amber_dependency?(shard_content : String) : Bool
      yaml = YAML.parse(shard_content)
      dependencies = yaml["dependencies"]?
      return false unless dependencies

      dependencies["amber"]? != nil
    rescue YAML::ParseException
      false
    end
  end
end
