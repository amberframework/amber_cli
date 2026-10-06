require "set"

require "./index_models"
require "./parse_api_type_name"
require "./resolve_return_types_for_api_index_methods"

module AmberLSP::Lookup
  struct APIResolution
    getter query : String
    getter resolution_kind : String
    getter type_summary : APIIndexType?
    getter list_of_methods : Array(APIIndexMethod)

    def initialize(
      @query : String,
      @resolution_kind : String,
      @type_summary : APIIndexType? = nil,
      @list_of_methods : Array(APIIndexMethod) = [] of APIIndexMethod,
    )
    end
  end

  class ResolveAPIQuery
    def initialize(@query : String, @list_of_layers : Array(APIIndexLayer))
    end

    def perform : APIResolution
      query = @query.strip
      return unknown_result(query) if query.empty?

      if match = query.match(/\A(.+)#([^.#]+)\z/)
        return resolve_instance_method(query, match[1], match[2])
      end

      if match = query.match(/\A(.+)\.([^.#]+)\z/)
        return resolve_class_method(query, match[1], match[2])
      end

      if query[0].uppercase?
        return resolve_type(query)
      end

      resolve_bare_method(query)
    end

    private def resolve_type(query : String) : APIResolution
      matching_types = types_named(query)
      type_summary = matching_types.first?
      return unknown_result(query) unless type_summary

      APIResolution.new(query, "type", type_summary)
    end

    private def resolve_instance_method(query : String, type_name : String, method_name : String) : APIResolution
      matching_types = types_named(type_name)
      return unknown_result(query) if matching_types.empty?

      methods = methods_named(matching_types, method_name, "instance")
      return found_result(query, "instance_method", methods, receiver_type(type_name, matching_types)) unless methods.empty?

      ancestor_types_for(matching_types).each do |ancestor_type|
        methods = methods_named([ancestor_type], method_name, "instance")
        return found_result(query, "instance_method", methods, receiver_type(type_name, matching_types)) unless methods.empty?
      end

      unknown_result(query)
    end

    private def resolve_class_method(query : String, type_name : String, method_name : String) : APIResolution
      matching_types = types_named(type_name)
      return unknown_result(query) if matching_types.empty?

      methods = methods_named(matching_types, method_name, "class")
      return found_result(query, "class_method", methods, receiver_type(type_name, matching_types)) unless methods.empty?

      ancestor_types = ancestor_types_for(matching_types)
      ancestor_types.each do |ancestor_type|
        methods = methods_named([ancestor_type], method_name, "class")
        return found_result(query, "class_method", methods, receiver_type(type_name, matching_types)) unless methods.empty?
      end

      methods = extended_module_methods(matching_types + ancestor_types, method_name)
      return found_result(query, "class_method", methods, receiver_type(type_name, matching_types)) unless methods.empty?

      macro_methods = methods_named(matching_types, method_name, "macro")
      return found_result(query, "class_method", macro_methods, receiver_type(type_name, matching_types)) unless macro_methods.empty?

      unknown_result(query)
    end

    private def resolve_bare_method(query : String) : APIResolution
      methods = [] of APIIndexMethod
      all_types.each do |type|
        methods.concat(methods_named([type], query, "instance"))
        methods.concat(methods_named([type], query, "class"))
        methods.concat(methods_named([type], query, "macro"))
      end

      APIResolution.new(query, "bare_method", nil, unique_methods(methods))
    end

    private def extended_module_methods(owner_types : Array(APIIndexType), method_name : String) : Array(APIIndexMethod)
      methods = [] of APIIndexMethod
      visited_module_names = Set(String).new

      owner_types.each do |owner_type|
        owner_type.list_of_extended_module_names.each do |module_name|
          next if visited_module_names.includes?(module_name)

          visited_module_names.add(module_name)
          types_named(module_name).each do |module_type|
            methods.concat(methods_named([module_type], method_name, "instance").map(&.as_extended_class_method))
          end
        end
      end

      unique_methods(methods)
    end

    private def ancestor_types_for(types : Array(APIIndexType)) : Array(APIIndexType)
      list_of_ancestors = [] of APIIndexType
      types.each do |type|
        type.list_of_ancestor_names.each do |ancestor_name|
          list_of_ancestors.concat(types_named(ancestor_name))
        end
      end
      unique_types(list_of_ancestors)
    end

    private def methods_named(types : Array(APIIndexType), method_name : String, method_kind : String) : Array(APIIndexMethod)
      methods = [] of APIIndexMethod
      types.each do |type|
        case method_kind
        when "instance"
          methods.concat(type.list_of_instance_methods.select { |method| method.name == method_name })
        when "class"
          methods.concat(type.list_of_class_methods.select { |method| method.name == method_name })
        when "macro"
          methods.concat(type.list_of_macros.select { |method| method.name == method_name })
        end
      end
      unique_methods(methods)
    end

    private def types_named(name : String) : Array(APIIndexType)
      normalized_name = normalize_type_name(name)
      matching_types = all_types.select do |type|
        normalize_type_name(type.name) == normalized_name
      end
      return matching_types unless matching_types.empty?

      base_name = base_type_name(normalized_name)
      all_types.select { |type| base_type_name(normalize_type_name(type.name)) == base_name }
    end

    private def all_types : Array(APIIndexType)
      @list_of_layers.flat_map(&.list_of_types)
    end

    private def unique_types(types : Array(APIIndexType)) : Array(APIIndexType)
      seen = Set(String).new
      types.select do |type|
        type_key = "#{type.name}\0#{type.source_layer}\0#{type.location_path}\0#{type.location_line}"
        next false if seen.includes?(type_key)

        seen.add(type_key)
        true
      end
    end

    private def unique_methods(methods : Array(APIIndexMethod)) : Array(APIIndexMethod)
      seen = Set(String).new
      methods.select do |method|
        method_key = [
          method.owner,
          method.name,
          method.method_kind,
          method.args_string,
          method.source_path,
          method.source_line.to_s,
        ].join("\0")
        next false if seen.includes?(method_key)

        seen.add(method_key)
        true
      end
    end

    private def normalize_type_name(name : String) : String
      name.sub(/\A::/, "")
    end

    private def base_type_name(name : String) : String
      ParseAPITypeName.new(name).perform.base_name
    end

    private def receiver_type(type_name : String, matching_types : Array(APIIndexType)) : String
      normalized_name = normalize_type_name(type_name)
      return normalized_name if normalized_name.includes?('(')

      if matching_type = matching_types.first?
        return matching_type.name
      end

      normalized_name
    end

    private def found_result(
      query : String,
      resolution_kind : String,
      methods : Array(APIIndexMethod),
      receiver_type : String? = nil,
    ) : APIResolution
      resolved_methods = ResolveReturnTypesForAPIIndexMethods.new(methods, receiver_type).perform
      APIResolution.new(query, resolution_kind, nil, resolved_methods)
    end

    private def unknown_result(query : String) : APIResolution
      APIResolution.new(query, "unknown")
    end
  end
end
