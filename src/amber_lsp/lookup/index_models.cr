require "json"

module AmberLSP::Lookup
  # :nodoc:
  struct CrystalDocsLocation
    include JSON::Serializable

    getter filename : String = ""
    @[JSON::Field(key: "line_number")]
    getter line_number : Int32 = 0
    getter url : String? = nil
  end

  # :nodoc:
  struct CrystalDocsTypeReference
    include JSON::Serializable

    getter kind : String = ""
    getter name : String = ""
    @[JSON::Field(key: "full_name")]
    getter full_name : String = ""
  end

  # :nodoc:
  struct CrystalDocsMethodDefinition
    include JSON::Serializable

    getter name : String = ""
    @[JSON::Field(key: "return_type")]
    getter return_type : String? = nil
  end

  # :nodoc:
  struct CrystalDocsMethod
    include JSON::Serializable

    getter name : String = ""
    getter? abstract : Bool = false
    @[JSON::Field(key: "args_string")]
    getter args_string : String? = nil
    getter doc : String? = nil
    getter location : CrystalDocsLocation? = nil
    @[JSON::Field(key: "def")]
    getter definition : CrystalDocsMethodDefinition? = nil
  end

  # :nodoc:
  struct CrystalDocsType
    include JSON::Serializable

    getter kind : String = ""
    getter name : String = ""
    @[JSON::Field(key: "full_name")]
    getter full_name : String = ""
    getter? abstract : Bool = false
    getter locations : Array(CrystalDocsLocation) = [] of CrystalDocsLocation
    getter ancestors : Array(CrystalDocsTypeReference) = [] of CrystalDocsTypeReference
    @[JSON::Field(key: "included_modules")]
    getter included_modules : Array(CrystalDocsTypeReference) = [] of CrystalDocsTypeReference
    @[JSON::Field(key: "extended_modules")]
    getter extended_modules : Array(CrystalDocsTypeReference) = [] of CrystalDocsTypeReference
    @[JSON::Field(key: "instance_methods")]
    getter instance_methods : Array(CrystalDocsMethod) = [] of CrystalDocsMethod
    @[JSON::Field(key: "class_methods")]
    getter class_methods : Array(CrystalDocsMethod) = [] of CrystalDocsMethod
    getter macros : Array(CrystalDocsMethod) = [] of CrystalDocsMethod
    getter types : Array(CrystalDocsType) = [] of CrystalDocsType

    def initialize(
      @kind : String = "",
      @name : String = "",
      @full_name : String = "",
      @abstract : Bool = false,
      @locations : Array(CrystalDocsLocation) = [] of CrystalDocsLocation,
      @ancestors : Array(CrystalDocsTypeReference) = [] of CrystalDocsTypeReference,
      @included_modules : Array(CrystalDocsTypeReference) = [] of CrystalDocsTypeReference,
      @extended_modules : Array(CrystalDocsTypeReference) = [] of CrystalDocsTypeReference,
      @instance_methods : Array(CrystalDocsMethod) = [] of CrystalDocsMethod,
      @class_methods : Array(CrystalDocsMethod) = [] of CrystalDocsMethod,
      @macros : Array(CrystalDocsMethod) = [] of CrystalDocsMethod,
      @types : Array(CrystalDocsType) = [] of CrystalDocsType,
    )
    end
  end

  # :nodoc:
  struct CrystalDocsExport
    include JSON::Serializable

    getter repository_name : String
    getter program : CrystalDocsType

    def initialize(
      @repository_name : String = "",
      @program : CrystalDocsType = CrystalDocsType.new,
    )
    end
  end

  # :nodoc:
  struct APIIndexMethod
    include JSON::Serializable

    getter owner : String
    getter name : String
    getter method_kind : String
    getter args_string : String
    getter return_type : String
    getter doc_line : String? = nil
    getter source_path : String
    getter source_line : Int32
    getter source_layer : String
    getter? abstract : Bool
    getter? macro : Bool

    def initialize(
      @owner : String,
      @name : String,
      @method_kind : String,
      @args_string : String,
      @return_type : String,
      @doc_line : String?,
      @source_path : String,
      @source_line : Int32,
      @source_layer : String,
      @abstract : Bool,
      @macro : Bool,
    )
    end

    def as_extended_class_method : APIIndexMethod
      APIIndexMethod.new(
        owner,
        name,
        "extended_class",
        args_string,
        return_type,
        doc_line,
        source_path,
        source_line,
        source_layer,
        abstract?,
        macro?,
      )
    end

    def lookup_reference : String
      separator = method_kind == "instance" ? "#" : "."
      "#{owner}#{separator}#{name}"
    end

    def lookup_label : String
      "#{lookup_reference}#{lookup_argument_list}"
    end

    def lookup_symbol_name : String
      "#{lookup_label}#{extension_annotation}"
    end

    def lookup_signature : String
      "#{lookup_label} : #{return_type.gsub("::Nil", "Nil")}#{extension_annotation}"
    end

    private def lookup_argument_list : String
      args_string.starts_with?('(') ? args_string : "(#{args_string})"
    end

    private def extension_annotation : String
      method_kind == "extended_class" ? " (class method via extend)" : ""
    end
  end

  # :nodoc:
  struct APIIndexType
    include JSON::Serializable

    getter name : String
    getter kind : String
    getter? abstract : Bool
    getter list_of_ancestor_names : Array(String)
    getter list_of_included_module_names : Array(String)
    getter list_of_extended_module_names : Array(String)
    getter location_path : String
    getter location_line : Int32
    getter source_layer : String
    getter list_of_instance_methods : Array(APIIndexMethod)
    getter list_of_class_methods : Array(APIIndexMethod)
    getter list_of_macros : Array(APIIndexMethod)

    def initialize(
      @name : String,
      @kind : String,
      @abstract : Bool,
      @list_of_ancestor_names : Array(String),
      @list_of_included_module_names : Array(String),
      @list_of_extended_module_names : Array(String),
      @location_path : String,
      @location_line : Int32,
      @source_layer : String,
      @list_of_instance_methods : Array(APIIndexMethod),
      @list_of_class_methods : Array(APIIndexMethod),
      @list_of_macros : Array(APIIndexMethod),
    )
    end
  end

  # :nodoc:
  struct APIIndexLayer
    include JSON::Serializable

    getter layer_kind : String
    getter layer_name : String
    getter layer_key : String
    getter root_path : String
    getter docs_flags : Array(String)
    getter list_of_types : Array(APIIndexType)

    def initialize(
      @layer_kind : String,
      @layer_name : String,
      @layer_key : String,
      @root_path : String,
      @docs_flags : Array(String),
      @list_of_types : Array(APIIndexType),
    )
    end
  end
end
