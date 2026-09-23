require "yaml"

module AmberLSP
  class ProjectContext
    getter root_path : String
    getter? amber_project : Bool
    getter shard_name : String?

    @shard_configuration : YAML::Any?

    def initialize(
      @root_path : String,
      @amber_project : Bool = false,
      @shard_name : String? = nil,
      @shard_configuration : YAML::Any? = nil,
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
        shard_configuration: shard_configuration,
      )
    rescue YAML::ParseException
      ProjectContext.new(root_path, amber_project: false)
    end

    def has_shard_declaration?(key_path : String, expected_value : String) : Bool
      shard_configuration = @shard_configuration
      return false unless shard_configuration

      current_value = shard_configuration
      key_path.split('.').each do |key|
        next_value = current_value[key]?
        return false unless next_value
        current_value = next_value
      end

      current_value.as_s? == expected_value
    rescue TypeCastError
      false
    end

    private def self.has_amber_dependency?(shard_configuration : YAML::Any) : Bool
      dependencies = shard_configuration["dependencies"]?
      return false unless dependencies

      dependencies["amber"]? != nil
    end
  end
end
