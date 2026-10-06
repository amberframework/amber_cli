require "digest/sha256"
require "json"
require "random/secure"

require "./index_models"

module AmberLSP::Lookup
  class APIIndexBuildError < Exception
  end

  class CalculateProjectLayerKey
    def initialize(@root_path : String, @docs_flags : Array(String), @compiler_version : String)
    end

    def perform : String
      root_path = File.expand_path(@root_path)
      list_of_index_paths = source_paths(root_path)
      key_material = ["project", @compiler_version, @docs_flags.sort.join("\0")]

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
    )
    end

    def perform : String
      key_material = [
        "library",
        @library_name,
        @locked_version_or_commit,
        @docs_flags.sort.join("\0"),
        @compiler_version,
      ]
      Digest::SHA256.hexdigest(key_material.join("\0"))
    end
  end

  class CalculateStandardLibraryLayerKey
    def initialize(@compiler_version : String, @docs_flags : Array(String) = [] of String)
    end

    def perform : String
      key_material = ["stdlib", @compiler_version, @docs_flags.sort.join("\0")]
      Digest::SHA256.hexdigest(key_material.join("\0"))
    end
  end

  struct CachedAPIIndexLayer
    getter layer : APIIndexLayer?
    getter freshness : String
    getter failure_reason : String?

    def initialize(@layer : APIIndexLayer?, @freshness : String, @failure_reason : String? = nil)
    end
  end

  # :nodoc:
  struct APIIndexCachePointer
    include JSON::Serializable

    getter key : String

    def initialize(@key : String)
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

      latest_path = File.join(directory_path, "latest.json")
      return CachedAPIIndexLayer.new(nil, "unavailable") unless File.file?(latest_path)

      pointer = APIIndexCachePointer.from_json(File.read(latest_path))
      stale_path = File.join(directory_path, "#{pointer.key}.json")
      stale_layer = load_matching_layer(stale_path, layer_kind, layer_name, pointer.key)
      return CachedAPIIndexLayer.new(nil, "unavailable") unless stale_layer

      CachedAPIIndexLayer.new(stale_layer, "stale")
    rescue ex : JSON::ParseException | IO::Error
      CachedAPIIndexLayer.new(nil, "unavailable", ex.message)
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

    private def safe_path_component(value : String) : String
      value.gsub(/[^A-Za-z0-9_-]/, "_")
    end

    private def write_atomically(path : String, contents : String) : Nil
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
