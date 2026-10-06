require "json"

require "./index_cache"
require "./index_models"
require "./resolve_api_query"

module AmberLSP::Lookup
  struct APIIndexLayerState
    include JSON::Serializable

    getter layer_kind : String
    getter layer_name : String
    getter layer_key : String
    getter freshness : String
    @[JSON::Field(emit_null: true)]
    getter failure_reason : String?

    def initialize(
      @layer_kind : String,
      @layer_name : String,
      @layer_key : String,
      @freshness : String,
      @failure_reason : String?,
    )
    end
  end

  struct LookupAnswer
    include JSON::Serializable

    getter query : String
    getter status : String
    getter freshness : String
    @[JSON::Field(emit_null: true)]
    getter type_summary : APIIndexType?
    @[JSON::Field(key: "entries")]
    getter list_of_entries : Array(APIIndexMethod)
    @[JSON::Field(key: "layers")]
    getter list_of_layers : Array(APIIndexLayerState)

    def initialize(
      @query : String,
      @status : String,
      @freshness : String,
      @type_summary : APIIndexType?,
      @list_of_entries : Array(APIIndexMethod),
      @list_of_layers : Array(APIIndexLayerState),
    )
    end
  end

  class AnswerAPIQuery
    def initialize(
      @query : String,
      @resolution : APIResolution,
      @list_of_layers : Array(CachedAPIIndexLayer),
    )
    end

    def perform : LookupAnswer
      answer_status = status
      answer_freshness = freshness
      list_of_layer_states = @list_of_layers.map do |cached_layer|
        APIIndexLayerState.new(
          cached_layer.layer_kind,
          cached_layer.layer_name,
          cached_layer.layer_key,
          cached_layer.freshness,
          cached_layer.failure_reason,
        )
      end

      LookupAnswer.new(
        @query,
        answer_status,
        answer_freshness,
        @resolution.type_summary,
        @resolution.list_of_methods,
        list_of_layer_states,
      )
    end

    private def status : String
      if @resolution.resolution_kind == "type" && @resolution.type_summary
        return "found"
      end

      if @resolution.resolution_kind == "bare_method"
        return @resolution.list_of_methods.empty? ? "unknown" : "candidates"
      end

      @resolution.list_of_methods.empty? ? "unknown" : "found"
    end

    private def freshness : String
      return "unavailable" if @list_of_layers.empty?

      return "unavailable" if @list_of_layers.any? { |layer| layer.freshness == "unavailable" }
      return "stale" if @list_of_layers.any? { |layer| layer.freshness == "stale" }

      return "fresh" if @list_of_layers.all? { |layer| layer.freshness == "fresh" }

      "unavailable"
    end
  end
end
