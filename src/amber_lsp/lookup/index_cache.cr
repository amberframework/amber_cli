require "digest/sha256"
require "json"
require "random/secure"

require "./index_models"

module AmberLSP::Lookup
  class APIIndexBuildError < Exception
  end

  class CalculateProjectLayerKey
    def initialize(
      @root_path : String,
      @docs_flags : Array(String),
      @compiler_version : String,
      @docs_entries : Array(String) = [] of String,
    )
    end

    def perform : String
      root_path = File.expand_path(@root_path)
      list_of_index_paths = source_paths(root_path)
      key_material = ["project", "docs-entries-v1", "resolved-return-types-v2", @compiler_version, @docs_flags.sort.join("\0")]
      key_material.concat(@docs_entries)

      list_of_index_paths.each do |path|
        relative_path = path.sub(root_path + "/", "")
        key_material << relative_path
        key_material << Digest::SHA256.hexdigest(File.read(path))
      end

      key_material << "shard.yml"
      shard_path = File.join(root_path, "shard.yml")
      key_material << (File.file?(shard_path) ? Digest::SHA256.hexdigest(File.read(shard_path)) : "missing")
      Digest::SHA256.hexdigest(key_material.join("\0"))
    end

    private def source_paths(root_path : String) : Array(String)
      list_of_paths = [] of String
      {"src", "config"}.each do |directory_name|
        directory_path = File.join(root_path, directory_name)
        next unless File.directory?(directory_path)

        list_of_paths.concat(Dir.glob(File.join(directory_path, "**", "*.cr")))
      end
      list_of_paths.sort
    end
  end

  class CalculateLibraryLayerKey
    def initialize(
      @library_name : String,
      @locked_version_or_commit : String,
      @docs_flags : Array(String),
      @compiler_version : String,
      @docs_entries : Array(String) = [] of String,
    )
    end

    def perform : String
      key_material = [
        "library",
        "docs-workspace-multi-entry-v2",
        "resolved-return-types-v2",
        @library_name,
        @locked_version_or_commit,
        @docs_flags.sort.join("\0"),
        @compiler_version,
      ]
      key_material.concat(@docs_entries)
      Digest::SHA256.hexdigest(key_material.join("\0"))
    end
  end

  class CalculateStandardLibraryLayerKey
    def initialize(@compiler_version : String, @docs_flags : Array(String) = [] of String)
    end

    def perform : String
      key_material = ["stdlib", "resolved-return-types-v2", @compiler_version, @docs_flags.sort.join("\0")]
      Digest::SHA256.hexdigest(key_material.join("\0"))
    end
  end

  struct CachedAPIIndexLayer
    getter layer : APIIndexLayer?
    getter freshness : String
    getter failure_reason : String?
    getter layer_kind : String
    getter layer_name : String
    getter layer_key : String

    def initialize(
      @layer : APIIndexLayer?,
      @freshness : String,
      @failure_reason : String? = nil,
      layer_kind : String? = nil,
      layer_name : String? = nil,
      layer_key : String? = nil,
    )
      if index_layer = @layer
        @layer_kind = layer_kind || index_layer.layer_kind
        @layer_name = layer_name || index_layer.layer_name
        @layer_key = layer_key || index_layer.layer_key
      else
        @layer_kind = layer_kind || ""
        @layer_name = layer_name || ""
        @layer_key = layer_key || ""
      end
    end
  end

  # :nodoc:
  struct APIIndexCachePointer
    include JSON::Serializable

    getter key : String

    def initialize(@key : String)
    end
  end

  # :nodoc:
  struct APIIndexCacheFailure
    include JSON::Serializable

    getter layer_kind : String
    getter layer_name : String
    getter layer_key : String
    getter failure_reason : String
    getter created_at_unix : Int64

    def initialize(
      @layer_kind : String,
      @layer_name : String,
      @layer_key : String,
      @failure_reason : String,
      @created_at_unix : Int64,
    )
    end
  end

  class APIIndexCache
    def initialize(@cache_root : String, @project_root_path : String)
    end

    def self.default_root : String
      File.join(Path.home.to_s, ".cache", "amber-lsp", "index")
    end

    def write_layer(layer : APIIndexLayer) : String
      directory_path = layer_directory(layer.layer_kind, layer.layer_name)
      Dir.mkdir_p(directory_path)

      layer_path = File.join(directory_path, "#{layer.layer_key}.json")
      write_atomically(layer_path, layer.to_json)

      failure_path = failure_marker_path(layer.layer_kind, layer.layer_name, layer.layer_key)
      File.delete(failure_path) if File.file?(failure_path)

      latest_path = File.join(directory_path, "latest.json")
      write_atomically(latest_path, APIIndexCachePointer.new(layer.layer_key).to_json)
      layer_path
    end

    def load_layer(layer_kind : String, layer_name : String, expected_key : String) : CachedAPIIndexLayer
      directory_path = layer_directory(layer_kind, layer_name)
      fresh_path = File.join(directory_path, "#{expected_key}.json")

      if File.file?(fresh_path)
        if layer = load_matching_layer(fresh_path, layer_kind, layer_name, expected_key)
          return CachedAPIIndexLayer.new(layer, "fresh")
        end
      end

      if failure = load_cached_failure(layer_kind, layer_name, expected_key)
        stale_layer = latest_layer(directory_path, layer_kind, layer_name)
        freshness = stale_layer ? "stale" : "unavailable"
        return CachedAPIIndexLayer.new(stale_layer, freshness, failure.failure_reason, layer_kind, layer_name, expected_key)
      end

      latest_path = File.join(directory_path, "latest.json")
      return CachedAPIIndexLayer.new(nil, "unavailable", nil, layer_kind, layer_name, expected_key) unless File.file?(latest_path)

      pointer = APIIndexCachePointer.from_json(File.read(latest_path))
      stale_path = File.join(directory_path, "#{pointer.key}.json")
      stale_layer = load_matching_layer(stale_path, layer_kind, layer_name, pointer.key)
      return CachedAPIIndexLayer.new(nil, "unavailable", nil, layer_kind, layer_name, expected_key) unless stale_layer

      CachedAPIIndexLayer.new(stale_layer, "stale")
    rescue ex : JSON::ParseException | IO::Error
      CachedAPIIndexLayer.new(nil, "unavailable", ex.message, layer_kind, layer_name, expected_key)
    end

    def write_failure(
      layer_kind : String,
      layer_name : String,
      layer_key : String,
      failure_reason : String,
    ) : Nil
      marker = APIIndexCacheFailure.new(
        layer_kind,
        layer_name,
        layer_key,
        failure_reason,
        Time.utc.to_unix,
      )
      write_atomically(failure_marker_path(layer_kind, layer_name, layer_key), marker.to_json)
    end

    private def load_cached_failure(
      layer_kind : String,
      layer_name : String,
      layer_key : String,
    ) : APIIndexCacheFailure?
      marker_path = failure_marker_path(layer_kind, layer_name, layer_key)
      return nil unless File.file?(marker_path)

      marker = APIIndexCacheFailure.from_json(File.read(marker_path))
      return nil unless marker.layer_kind == layer_kind
      return nil unless marker.layer_name == layer_name
      return nil unless marker.layer_key == layer_key
      return nil if Time.utc.to_unix - marker.created_at_unix > 300

      marker
    rescue ex : JSON::ParseException | IO::Error
      nil
    end

    private def latest_layer(directory_path : String, layer_kind : String, layer_name : String) : APIIndexLayer?
      latest_path = File.join(directory_path, "latest.json")
      return nil unless File.file?(latest_path)

      pointer = APIIndexCachePointer.from_json(File.read(latest_path))
      load_matching_layer(
        File.join(directory_path, "#{pointer.key}.json"),
        layer_kind,
        layer_name,
        pointer.key,
      )
    rescue ex : JSON::ParseException | IO::Error
      nil
    end

    private def load_matching_layer(
      layer_path : String,
      expected_kind : String,
      expected_name : String,
      expected_key : String,
    ) : APIIndexLayer?
      return nil unless File.file?(layer_path)

      layer = APIIndexLayer.from_json(File.read(layer_path))
      return nil unless layer.layer_kind == expected_kind
      return nil unless layer.layer_name == expected_name
      return nil unless layer.layer_key == expected_key

      layer
    rescue ex : JSON::ParseException | IO::Error
      nil
    end

    private def layer_directory(layer_kind : String, layer_name : String) : String
      case layer_kind
      when "stdlib"
        File.join(@cache_root, "stdlib")
      when "library"
        File.join(@cache_root, "libraries", safe_path_component(layer_name))
      else
        project_key = Digest::SHA256.hexdigest(File.expand_path(@project_root_path))
        File.join(@cache_root, "projects", project_key, safe_path_component(layer_kind), safe_path_component(layer_name))
      end
    end

    private def failure_marker_path(layer_kind : String, layer_name : String, layer_key : String) : String
      project_key = Digest::SHA256.hexdigest(File.expand_path(@project_root_path))
      File.join(
        @cache_root,
        "failures",
        project_key,
        safe_path_component(layer_kind),
        safe_path_component(layer_name),
        "#{layer_key}.json",
      )
    end

    private def safe_path_component(value : String) : String
      value.gsub(/[^A-Za-z0-9_-]/, "_")
    end

    private def write_atomically(path : String, contents : String) : Nil
      Dir.mkdir_p(File.dirname(path))
      temp_path = "#{path}.tmp-#{Random::Secure.hex(12)}"
      begin
        File.write(temp_path, contents)
        File.rename(temp_path, path)
      rescue ex : IO::Error
        if File.file?(temp_path)
          File.delete(temp_path)
        end
        raise ex
      end
    end
  end
end
