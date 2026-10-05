# :nodoc:
require "json"
require "yaml"

module AmberCLI::MCP
  # Reads facts about an Amber application from an explicit directory.
  #
  # Every method takes the application root as an argument. The MCP server answers
  # concurrent requests for different applications from one process, so nothing
  # here may consult or change the working directory — `Dir.cd` is process-global
  # and two in-flight requests would corrupt each other's view of the filesystem.
  #
  # Nothing here calls `exit` either. `Amber::CLI.config` exits the process on a
  # malformed `.amber.yml`, which inside a long-running server would take the
  # server down with it, so this reads and rescues instead.
  class ApplicationInspector
    # Files that, taken together, identify a directory as an Amber application.
    SHARD_FILE  = "shard.yml"
    AMBER_FILE  = ".amber.yml"
    ROUTES_FILE = File.join("config", "routes.cr")

    getter path : String

    @shard_yaml : YAML::Any?
    @amber_yaml : YAML::Any?

    def initialize(path : String)
      @path = File.expand_path(path)
      # Parsed once up front: memoizing a nullable result needs a separate
      # loaded-flag to avoid re-reading a missing file on every accessor.
      @shard_yaml = read_yaml(File.join(@path, SHARD_FILE))
      @amber_yaml = read_yaml(File.join(@path, AMBER_FILE))
    end

    def exists? : Bool
      Dir.exists?(@path)
    end

    def shard_path : String
      File.join(@path, SHARD_FILE)
    end

    def amber_config_path : String
      File.join(@path, AMBER_FILE)
    end

    def routes_path : String
      File.join(@path, ROUTES_FILE)
    end

    # Whether this looks like an Amber application: a shard that depends on
    # `amber`, or the `.amber.yml` the CLI writes.
    def amber_application? : Bool
      return false unless exists?
      return true if File.exists?(amber_config_path)

      !amber_dependency.nil?
    end

    # The declared `amber` dependency, as a version or branch string.
    def amber_dependency : String?
      dependencies = shard_yaml.try(&.["dependencies"]?).try(&.as_h?)
      return unless dependencies

      entry = dependencies.find { |key, _| key.as_s? == "amber" }
      return unless entry

      spec = entry[1].as_h?
      return "unspecified" unless spec

      if version = spec["version"]?.try(&.as_s?)
        version
      elsif branch = spec["branch"]?.try(&.as_s?)
        "branch: #{branch}"
      elsif commit = spec["commit"]?.try(&.as_s?)
        "commit: #{commit}"
      else
        "unspecified"
      end
    end

    def application_name : String?
      shard_yaml.try(&.["name"]?).try(&.as_s?)
    end

    def application_version : String?
      shard_yaml.try(&.["version"]?).try(&.to_s)
    end

    # Database adapter recorded by `amber new`, defaulting the way `Amber::CLI::Config` does.
    def database_adapter : String
      amber_yaml.try(&.["database"]?).try(&.as_s?) || "pg"
    end

    def template_language : String
      amber_yaml.try(&.["language"]?).try(&.as_s?) || "ecr"
    end

    def model_layer : String
      amber_yaml.try(&.["model"]?).try(&.as_s?) || "none"
    end

    # Every dependency name declared in the shard, for orientation.
    def dependency_names : Array(String)
      shard_yaml.try(&.["dependencies"]?).try(&.as_h?)
        .try(&.keys.compact_map(&.as_s?)) || [] of String
    end

    # A structured summary suitable for a tool result.
    def to_json_payload : JSON::Any
      unless exists?
        return JSON.parse({
          "path"             => @path,
          "exists"           => false,
          "amberApplication" => false,
        }.to_json)
      end

      JSON.parse({
        "path"             => @path,
        "exists"           => true,
        "amberApplication" => amber_application?,
        "name"             => application_name,
        "version"          => application_version,
        "amberDependency"  => amber_dependency,
        "databaseAdapter"  => database_adapter,
        "templateLanguage" => template_language,
        "modelLayer"       => model_layer,
        "dependencies"     => dependency_names,
        "files"            => {
          "shardYml"      => File.exists?(shard_path),
          "amberYml"      => File.exists?(amber_config_path),
          "configRoutes"  => File.exists?(routes_path),
          "srcDirectory"  => Dir.exists?(File.join(@path, "src")),
          "specDirectory" => Dir.exists?(File.join(@path, "spec")),
        },
      }.to_json)
    end

    private def shard_yaml : YAML::Any?
      @shard_yaml
    end

    private def amber_yaml : YAML::Any?
      @amber_yaml
    end

    # A malformed YAML file is a fact about the application, not a server fault.
    private def read_yaml(file : String) : YAML::Any?
      return unless File.exists?(file)
      YAML.parse(File.read(file))
    rescue YAML::ParseException
      nil
    end
  end
end
