module AmberCLI::Native
  module Naming
    extend self

    def pascalize(value : String, fallback : String = "NativeApp") : String
      parts = normalized_parts(value)
      return fallback if parts.empty?

      type_name = parts.map { |part| capitalize(part) }.join
      type_name = "#{fallback}#{type_name}" if type_name.matches?(/^\d/)
      type_name
    end

    def slugify(value : String, fallback : String) : String
      slug = value.strip.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
      slug.empty? ? fallback : slug
    end

    def bundle_identifier_segment(value : String, fallback : String = "nativeapp") : String
      segment = value.strip.downcase.gsub(/[^a-z0-9]+/, ".").gsub(/\.+/, ".").gsub(/^\.+|\.+$/, "")
      segment.empty? ? fallback : segment
    end

    def swift_module_name(value : String, suffix : String, fallback : String = "AssetPipeline") : String
      base = pascalize(value, fallback)
      base = "#{fallback}#{base}" if base.matches?(/^\d/)
      "#{base}#{suffix}"
    end

    def swift_string_literal(value : String) : String
      escaped = value.gsub("\\", "\\\\").gsub("\"", "\\\"").gsub("\n", "\\n")
      %("#{escaped}")
    end

    private def normalized_parts(value : String) : Array(String)
      value
        .gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
        .gsub(/[^A-Za-z0-9]+/, "_")
        .split('_')
        .reject(&.empty?)
    end

    private def capitalize(value : String) : String
      return value if value.empty?
      value[0].upcase + value[1..].downcase
    end
  end
end
