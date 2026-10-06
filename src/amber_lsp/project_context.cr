require "yaml"

module AmberLSP
  class ProjectContext
    getter root_path : String
    getter? amber_project : Bool
    getter shard_name : String?
    getter failure_reason : String?

    def initialize(
      @root_path : String,
      @amber_project : Bool = false,
      @shard_name : String? = nil,
      @failure_reason : String? = nil,
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
    rescue ex : YAML::ParseException
      ProjectContext.new(root_path, failure_reason: "shard.yml is invalid: #{ex.message}")
    rescue ex : File::Error
      ProjectContext.new(root_path, failure_reason: "shard.yml could not be read: #{ex.message}")
    end

    def self.detect_for_file(file_path : String) : ProjectContext
      detect(project_root_for_file(file_path))
    end

    def self.project_root_for_file(file_path : String) : String
      current_path = File.expand_path(file_path)
      current_path = File.dirname(current_path) unless File.directory?(current_path)

      loop do
        return current_path if File.file?(File.join(current_path, "shard.yml"))

        parent_path = File.dirname(current_path)
        return current_path if parent_path == current_path
        current_path = parent_path
      end
    end

    private def self.has_amber_dependency?(shard_configuration : YAML::Any) : Bool
      dependencies = shard_configuration["dependencies"]?
      return false unless dependencies

      dependencies["amber"]? != nil
    end
  end
end
