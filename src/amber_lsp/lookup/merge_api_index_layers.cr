require "set"

require "./index_models"

module AmberLSP::Lookup
  class MergeAPIIndexLayers
    def initialize(
      @list_of_layers : Array(APIIndexLayer),
      @list_of_entry_failures : Array(APIIndexEntryFailure) = [] of APIIndexEntryFailure,
    )
    end

    def perform : APIIndexLayer
      first_layer = @list_of_layers.first? || raise APIIndexBuildError.new("No Crystal docs entries succeeded")
      list_of_types_by_name = {} of String => APIIndexType
      list_of_type_names = [] of String

      @list_of_layers.each do |layer|
        layer.list_of_types.each do |type|
          if existing_type = list_of_types_by_name[type.name]?
            list_of_types_by_name[type.name] = merge_types(existing_type, type)
          else
            list_of_type_names << type.name
            list_of_types_by_name[type.name] = type
          end
        end
      end

      APIIndexLayer.new(
        first_layer.layer_kind,
        first_layer.layer_name,
        first_layer.layer_key,
        first_layer.root_path,
        first_layer.docs_flags,
        list_of_type_names.map { |name| list_of_types_by_name[name] },
        @list_of_entry_failures,
      )
    end

    private def merge_types(first_type : APIIndexType, next_type : APIIndexType) : APIIndexType
      APIIndexType.new(
        first_type.name,
        first_type.kind,
        first_type.abstract? || next_type.abstract?,
        (first_type.list_of_ancestor_names + next_type.list_of_ancestor_names).uniq,
        (first_type.list_of_included_module_names + next_type.list_of_included_module_names).uniq,
        (first_type.list_of_extended_module_names + next_type.list_of_extended_module_names).uniq,
        first_type.location_path.empty? ? next_type.location_path : first_type.location_path,
        first_type.location_line == 0 ? next_type.location_line : first_type.location_line,
        first_type.source_layer,
        deduplicate_methods(first_type.list_of_instance_methods + next_type.list_of_instance_methods),
        deduplicate_methods(first_type.list_of_class_methods + next_type.list_of_class_methods),
        deduplicate_methods(first_type.list_of_macros + next_type.list_of_macros),
      )
    end

    private def deduplicate_methods(list_of_methods : Array(APIIndexMethod)) : Array(APIIndexMethod)
      seen = Set(Tuple(String, String, String)).new
      list_of_methods.select do |method|
        seen.add?({method.owner, method.name, method.args_string})
      end
    end
  end
end
