require "mutex"
require "./build_layered_api_index"

module AmberLSP::Lookup
  class APIIndexService
    def initialize(
      @cache_root : String = APIIndexCache.default_root,
      @layer_builder : Proc(String, Array(CachedAPIIndexLayer))? = nil,
    )
      @mutex = Mutex.new
      @layers_by_root = {} of String => Array(CachedAPIIndexLayer)
      @building_generation_by_root = {} of String => Int64
      @latest_generation_by_root = {} of String => Int64
    end

    def layers_for(root_path : String) : Array(CachedAPIIndexLayer)?
      normalized_root = File.expand_path(root_path)
      cached_layers : Array(CachedAPIIndexLayer)? = nil
      build_generation : Int64? = nil

      @mutex.synchronize do
        cached_layers = @layers_by_root[normalized_root]?
        unless cached_layers || @building_generation_by_root.has_key?(normalized_root)
          next_generation = (@latest_generation_by_root[normalized_root]? || 0_i64) + 1
          @latest_generation_by_root[normalized_root] = next_generation
          @building_generation_by_root[normalized_root] = next_generation
          build_generation = next_generation
        end
      end

      if generation = build_generation
        spawn do
          build_and_store(normalized_root, generation)
        end
      end

      cached_layers
    end

    def seed(root_path : String, layers : Array(CachedAPIIndexLayer)) : Nil
      normalized_root = File.expand_path(root_path)
      @mutex.synchronize do
        @layers_by_root[normalized_root] = layers
        @latest_generation_by_root[normalized_root] = (@latest_generation_by_root[normalized_root]? || 0_i64) + 1
        @building_generation_by_root.delete(normalized_root)
      end
    end

    def invalidate(root_path : String) : Nil
      normalized_root = File.expand_path(root_path)
      @mutex.synchronize do
        @layers_by_root.delete(normalized_root)
        @latest_generation_by_root[normalized_root] = (@latest_generation_by_root[normalized_root]? || 0_i64) + 1
        @building_generation_by_root.delete(normalized_root)
      end
    end

    private def build_and_store(root_path : String, generation : Int64) : Nil
      list_of_layers = if builder = @layer_builder
                         builder.call(root_path)
                       else
                         BuildLayeredAPIIndex.new(root_path, @cache_root).perform
                       end
      @mutex.synchronize do
        if @building_generation_by_root[root_path]? == generation
          @layers_by_root[root_path] = list_of_layers
          @building_generation_by_root.delete(root_path)
        end
      end
    rescue ex : Exception
      unavailable_layer = CachedAPIIndexLayer.new(
        nil,
        "unavailable",
        ex.message || "API index build failed",
        "project",
        File.basename(root_path),
        "",
      )
      @mutex.synchronize do
        if @building_generation_by_root[root_path]? == generation
          @layers_by_root[root_path] = [unavailable_layer]
          @building_generation_by_root.delete(root_path)
        end
      end
    end
  end
end
