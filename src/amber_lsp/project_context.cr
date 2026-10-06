require "yaml"

module AmberLSP
  class ProjectContext
    STACK_SHARD_NAMES = [
      "amber",
      "amber_router",
      "grant",
      "gemma",
      "asset_pipeline",
      "micrate",
      "quartz_mailer",
    ]

    getter root_path : String
    getter? amber_project : Bool
    getter? stack_project : Bool
    getter shard_name : String?
    getter failure_reason : String?

    def initialize(
      @root_path : String,
      @amber_project : Bool = false,
      @shard_name : String? = nil,
      @failure_reason : String? = nil,
      @stack_project : Bool = false,
    )
    end

    def self.detect(root_path : String) : ProjectContext
      shard_path = File.join(root_path, "shard.yml")

      unless File.exists?(shard_path)
        return ProjectContext.new(root_path, amber_project: false)
      end

      shard_configuration = YAML.parse(File.read(shard_path))
      shard_name = shard_configuration["name"]?.try(&.as_s?)
      list_of_dependency_names = dependency_names(shard_configuration)
      is_amber = shard_name == "amber" || list_of_dependency_names.includes?("amber")
      is_stack = stack_project_named?(shard_name) ||
                 list_of_dependency_names.any? { |dependency_name| STACK_SHARD_NAMES.includes?(dependency_name) }

      ProjectContext.new(
        root_path,
        amber_project: is_amber,
        shard_name: shard_name,
        stack_project: is_stack,
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

    private def self.stack_project_named?(shard_name : String?) : Bool
      return false unless shard_name

      STACK_SHARD_NAMES.includes?(shard_name) || shard_name == "amber_cli"
    end

    private def self.dependency_names(shard_configuration : YAML::Any) : Array(String)
      dependencies = shard_configuration["dependencies"]?
      return [] of String unless dependencies

      dependency_hash = dependencies.as_h?
      return [] of String unless dependency_hash

      dependency_hash.keys.compact_map(&.as_s?)
    end
  end
end
