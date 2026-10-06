require "./index_models"
require "./resolve_api_return_type"

module AmberLSP::Lookup
  # :nodoc:
  class ResolveReturnTypesForAPIIndexMethods
    def initialize(
      @list_of_methods : Array(APIIndexMethod),
      @receiver_type : String?,
    )
    end

    def perform : Array(APIIndexMethod)
      @list_of_methods.map do |method|
        resolved_return_type = ResolveAPIIndexReturnType.new(
          method.declared_return_type,
          @receiver_type,
          method.owner,
        ).perform
        method.with_resolved_return_type(resolved_return_type)
      end
    end
  end
end
