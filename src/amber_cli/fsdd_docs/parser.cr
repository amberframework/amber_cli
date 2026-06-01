require "json"

module AmberCLI::FSDDDocs
  class FSDDSections
    getter personas : String?
    getter requires : String?
    getter since_version : String?
    getter ramp : String?
    getter use : String?
    getter result : String?
    getter story : String?
    getter summary : String?

    def initialize(
      @personas = nil,
      @requires = nil,
      @since_version = nil,
      @ramp = nil,
      @use = nil,
      @result = nil,
      @story = nil,
      @summary = nil
    )
    end

    def has_fsdd_content? : Bool
      [personas, requires, since_version, ramp, use, result, story].any?
    end
  end

  class ParsedMethod
    getter name : String
    getter args_string : String
    getter return_type : String?
    getter visibility : String
    getter location : String?
    getter doc : String?
    getter fsdd : FSDDSections
    getter is_class_method : Bool

    def initialize(
      @name,
      @args_string,
      @return_type,
      @visibility,
      @location,
      @doc,
      @fsdd,
      @is_class_method
    )
    end

    def signature : String
      rt = return_type
      if rt && !rt.empty?
        "#{name}#{args_string} : #{rt}"
      else
        "#{name}#{args_string}"
      end
    end

    def kind_label : String
      is_class_method ? "class" : "instance"
    end
  end

  class ParsedType
    getter name : String
    getter full_name : String
    getter kind : String
    getter summary : String?
    getter doc : String?
    getter fsdd : FSDDSections
    getter locations : Array(String)
    getter methods : Array(ParsedMethod)

    def initialize(
      @name,
      @full_name,
      @kind,
      @summary,
      @doc,
      @fsdd,
      @locations,
      @methods
    )
    end

    # Filename-safe slug: replaces :: with - for flat output
    def slug : String
      full_name.gsub("::", "-")
    end

    def primary_location : String?
      locations.first?
    end
  end

  class Parser
    def self.parse_file(path : String) : Array(ParsedType)
      parse_json(JSON.parse(File.read(path)))
    end

    def self.parse_json(json : JSON::Any) : Array(ParsedType)
      program = json["program"]?
      return [] of ParsedType unless program

      types_json = program["types"]?
      return [] of ParsedType unless types_json

      result = [] of ParsedType
      types_json.as_a.each do |type_json|
        result.concat(parse_type_recursive(type_json))
      end
      result
    end

    def self.extract_fsdd_sections(doc : String?) : FSDDSections
      return FSDDSections.new unless doc && !doc.empty?

      FSDDSections.new(
        personas: extract_label(doc, "Personas"),
        requires: extract_label(doc, "Requires"),
        since_version: extract_label(doc, "Since"),
        ramp: extract_label(doc, "Ramp"),
        use: extract_label(doc, "Use"),
        result: extract_label(doc, "Result"),
        story: extract_story_block(doc),
        summary: extract_summary(doc)
      )
    end

    private def self.parse_type_recursive(type_json : JSON::Any) : Array(ParsedType)
      result = [] of ParsedType

      name = type_json["name"]?.try(&.as_s?) || ""
      full_name = type_json["full_name"]?.try(&.as_s?) || name
      kind = type_json["kind"]?.try(&.as_s?) || "class"
      summary = type_json["summary"]?.try(&.as_s?)
      doc = type_json["doc"]?.try(&.as_s?)

      locations = [] of String
      if locs_json = type_json["locations"]?.try(&.as_a?)
        locs_json.each do |loc|
          if loc_h = loc.as_h?
            fn = loc_h["filename"]?.try(&.as_s?)
            ln = loc_h["line_number"]?.try(&.as_i?)
            locations << "#{fn}:#{ln}" if fn && ln
          end
        end
      end

      methods = [] of ParsedMethod

      if im_json = type_json["instance_methods"]?
        im_json.as_a.each do |m|
          methods << parse_method(m, is_class_method: false)
        end
      end

      if cm_json = type_json["class_methods"]?
        cm_json.as_a.each do |m|
          methods << parse_method(m, is_class_method: true)
        end
      end

      fsdd = extract_fsdd_sections(doc)
      result << ParsedType.new(name, full_name, kind, summary, doc, fsdd, locations, methods)

      if nested_json = type_json["types"]?
        nested_json.as_a.each do |nested|
          result.concat(parse_type_recursive(nested))
        end
      end

      result
    end

    private def self.parse_method(m : JSON::Any, is_class_method : Bool) : ParsedMethod
      name = m["name"]?.try(&.as_s?) || ""
      args_string = m["args_string"]?.try(&.as_s?) || "()"
      doc = m["doc"]?.try(&.as_s?)

      def_h = m["def"]?.try(&.as_h?)
      return_type = def_h.try { |d| d["return_type"]?.try(&.as_s?) }
      visibility = def_h.try { |d| d["visibility"]?.try(&.as_s?) } || "Public"

      location : String? = nil
      if loc_h = m["location"]?.try(&.as_h?)
        fn = loc_h["filename"]?.try(&.as_s?)
        ln = loc_h["line_number"]?.try(&.as_i?)
        location = "#{fn}:#{ln}" if fn && ln
      end

      fsdd = extract_fsdd_sections(doc)
      ParsedMethod.new(name, args_string, return_type, visibility, location, doc, fsdd, is_class_method)
    end

    private def self.extract_label(text : String, label : String) : String?
      text.each_line do |line|
        if line.includes?("**#{label}:**")
          parts = line.split("**#{label}:**", 2)
          if parts.size == 2
            val = parts[1].strip
            return val unless val.empty?
          end
        end
      end
      nil
    end

    private def self.extract_story_block(text : String) : String?
      idx = text.index("Refined story")
      return nil unless idx

      start = idx + "Refined story".size
      # Skip colon and whitespace
      while start < text.size
        ch = text[start]
        break unless ch == ':' || ch == ' ' || ch == '\n' || ch == '\r'
        start += 1
      end

      remaining = text[start..]
      val = if end_idx = remaining.index(/\*\*\w+:\*\*/)
        remaining[0...end_idx].strip
      else
        remaining.strip
      end

      val.empty? ? nil : val
    end

    private def self.extract_summary(text : String) : String?
      text.each_line do |line|
        stripped = line.strip
        next if stripped.empty?
        next if stripped.starts_with?("**")
        return stripped
      end
      nil
    end
  end
end
