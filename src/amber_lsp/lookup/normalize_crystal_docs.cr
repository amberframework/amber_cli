require "./index_cache"
require "./parse_api_type_name"

module AmberLSP::Lookup
  class NormalizeCrystalDocs
    def initialize(
      @docs_json : String,
      @root_path : String,
      @layer_kind : String,
      @layer_name : String,
      @layer_key : String,
      @docs_flags : Array(String),
      @docs_working_directory : String? = nil,
      @source_path_mappings : Hash(String, String) = {} of String => String,
    )
    end

    def perform : APIIndexLayer
      export = CrystalDocsExport.from_json(@docs_json)
      list_of_types = [] of APIIndexType
      append_types_from(export.program, list_of_types)

      APIIndexLayer.new(
        @layer_kind,
        @layer_name,
        @layer_key,
        @root_path,
        @docs_flags,
        list_of_types,
      )
    end

    private def append_types_from(parent : CrystalDocsType, list_of_types : Array(APIIndexType)) : Nil
      parent.types.each do |docs_type|
        next if docs_type.locations.empty?

        if normalized_type = normalize_type(docs_type)
          list_of_types << normalized_type
        end
        append_types_from(docs_type, list_of_types)
      end
    end

    private def normalize_type(docs_type : CrystalDocsType) : APIIndexType?
      list_of_type_locations = docs_type.locations.compact_map do |location|
        path = source_path(location.filename)
        next unless include_library_source_path?(path)

        {path, location.line_number}
      end
      list_of_instance_methods = normalize_methods(docs_type, docs_type.instance_methods, "instance", false)
      list_of_class_methods = normalize_methods(docs_type, docs_type.class_methods, "class", false) +
                              normalize_methods(docs_type, docs_type.constructors, "class", false, docs_type.full_name)
      list_of_macros = normalize_methods(docs_type, docs_type.macros, "macro", true)

      location_path = ""
      location_line = 0
      if type_location = list_of_type_locations.first?
        location_path = type_location[0]
        location_line = type_location[1]
      elsif method_location = (list_of_instance_methods + list_of_class_methods + list_of_macros).first?
        location_path = method_location.source_path
        location_line = method_location.source_line
      else
        return nil
      end

      APIIndexType.new(
        docs_type.full_name,
        docs_type.kind,
        docs_type.abstract?,
        docs_type.ancestors.map(&.full_name),
        included_module_names(docs_type, location_path),
        docs_type.extended_modules.map(&.full_name),
        location_path,
        location_line,
        @layer_name,
        list_of_instance_methods,
        list_of_class_methods,
        list_of_macros,
      )
    end

    private def normalize_methods(
      docs_type : CrystalDocsType,
      docs_methods : Array(CrystalDocsMethod),
      method_kind : String,
      is_macro : Bool,
      return_type_override : String? = nil,
    ) : Array(APIIndexMethod)
      docs_methods.compact_map do |docs_method|
        location = docs_method.location
        next unless location
        path = source_path(location.filename)
        next unless include_library_source_path?(path)

        doc_line = first_doc_line(docs_method.doc)
        definition = docs_method.definition
        return_type = return_type_override || (definition ? definition.return_type : nil)
        declared_return_type = if return_type && !return_type.strip.empty?
                                 return_type
                               else
                                 UNKNOWN_API_RETURN_TYPE
                               end

        APIIndexMethod.new(
          docs_type.full_name,
          docs_method.name,
          method_kind,
          method_arguments(docs_method.args_string),
          declared_return_type,
          doc_line,
          path,
          location.line_number,
          @layer_name,
          docs_method.abstract?,
          is_macro,
        )
      end
    end

    private def include_library_source_path?(path : String) : Bool
      return true unless @layer_kind == "library"

      expanded_path = File.expand_path(path)
      library_root = File.expand_path(@root_path)
      return true if path_is_within?(expanded_path, library_root)

      linked_library_root = File.dirname(library_root)
      return false if path_is_within?(expanded_path, linked_library_root)

      known_roots = @source_path_mappings.values.map { |root| File.expand_path(root) }
      return false if known_roots.any? { |root| path_is_within?(expanded_path, root) }

      raise APIIndexBuildError.new("Library docs entry path is outside known roots: #{path}")
    end

    private def path_is_within?(path : String, root : String) : Bool
      normalized_root = File.expand_path(root)
      return true if path == normalized_root

      root_prefix = normalized_root == "/" ? normalized_root : "#{normalized_root}/"
      path.starts_with?(root_prefix)
    end

    private def included_module_names(docs_type : CrystalDocsType, location_path : String) : Array(String)
      module_names = docs_type.included_modules.map(&.full_name)
      type_name = ParseAPITypeName.new(docs_type.full_name).perform
      return module_names unless type_name.base_name == "Grant::Collection"
      return module_names unless source_forwards_collection_to_array?(location_path)

      type_parameter = type_name.list_of_type_arguments.first?
      # Crystal docs omits macro-forwarded methods; Grant::Collection forwards its Array(M) surface.
      module_names << "Enumerable(#{type_parameter})" if type_parameter
      module_names.uniq
    end

    private def source_forwards_collection_to_array?(source_path : String) : Bool
      return false if source_path.empty? || !File.file?(source_path)

      File.read(source_path).lines.any? do |line|
        line.matches?(/\A\s*forward_missing_to\s+collection\b/)
      end
    rescue ex : IO::Error
      false
    end

    private def method_arguments(args_string : String?) : String
      return "()" unless args_string

      args_string.sub(/\)\s*:\s*.+\z/, ")")
    end

    private def first_doc_line(doc : String?) : String?
      return nil unless doc

      first_line = doc.split('\n', 2).first?.try(&.strip)
      return nil if first_line.nil? || first_line.empty?

      first_line
    end

    private def source_path(filename : String) : String
      base_path = @docs_working_directory || @root_path
      expanded_path = Path[filename].absolute? ? File.expand_path(filename) : File.expand_path(filename, base_path)

      @source_path_mappings.each do |workspace_path, source_path|
        next unless expanded_path == workspace_path || expanded_path.starts_with?(workspace_path + "/")

        relative_path = expanded_path == workspace_path ? "" : expanded_path[(workspace_path.size + 1)..]
        return File.expand_path(relative_path, source_path)
      end

      return expanded_path if Path[filename].absolute?

      File.expand_path(filename, @root_path)
    end
  end
end
