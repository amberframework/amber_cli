require "yaml"

module AmberLSP::Lookup
  # :nodoc:
  struct ProjectShardTarget
    include YAML::Serializable

    getter main : String = ""
  end

  # :nodoc:
  struct ProjectShardDependency
    include YAML::Serializable
  end

  # :nodoc:
  struct ProjectShardManifest
    include YAML::Serializable

    getter name : String = ""
    getter version : String = "0.0.0"
    getter dependencies : Hash(String, ProjectShardDependency) = {} of String => ProjectShardDependency
    getter targets : Hash(String, ProjectShardTarget) = {} of String => ProjectShardTarget

    def initialize(
      @name : String = "",
      @version : String = "0.0.0",
      @dependencies : Hash(String, ProjectShardDependency) = {} of String => ProjectShardDependency,
      @targets : Hash(String, ProjectShardTarget) = {} of String => ProjectShardTarget,
    )
    end
  end

  # :nodoc:
  struct LockedShard
    include YAML::Serializable

    getter version : String = ""
  end

  # :nodoc:
  struct ShardLockfile
    include YAML::Serializable

    getter shards : Hash(String, LockedShard) = {} of String => LockedShard
  end
end
