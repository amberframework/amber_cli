require "yaml"

module AmberLSP
  class ProjectContext
    getter root_path : String
    getter? amber_project : Bool
    getter shard_name : String?

    def initialize(
      @root_path : String,
      @amber_project : Bool = false,
      @shard_name : String? = nil,
    )
    end

    def self.detect(root_path : String) : ProjectContext
      shard_path = File.join(root_path, "shard.yml")

      unless File.exists?(shard_path)
        return ProjectContext.new(root_path, amber_project: false)
      end

      shard_configuration = YAML.parse(File.read(shard_path))
      is_amber = has_amber_dependency?(shard_configuration)
      shard_name = shard_configuration["name"]?.try(&.as_s?)

      ProjectContext.new(
        root_path,
        amber_project: is_amber,
        shard_name: shard_name,
      )
    rescue YAML::ParseException
      ProjectContext.new(root_path, amber_project: false)
    end

    private def self.has_amber_dependency?(shard_configuration : YAML::Any) : Bool
      dependencies = shard_configuration["dependencies"]?
      return false unless dependencies

      dependencies["amber"]? != nil
    end
  end
end
