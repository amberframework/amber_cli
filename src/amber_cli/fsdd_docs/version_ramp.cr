require "./parser"

module AmberCLI::FSDDDocs
  class VersionEntry
    getter key : String
    getter versions : Array(String)
    getter first_version : String

    def initialize(@key : String, @versions : Array(String))
      @first_version = @versions.first? || ""
    end

    def present_in?(version : String) : Bool
      @versions.includes?(version)
    end
  end

  class VersionRamp
    getter versions : Array(String)
    getter entries : Hash(String, VersionEntry)

    def initialize(@versions : Array(String), @entries : Hash(String, VersionEntry))
    end

    def self.empty : VersionRamp
      new([] of String, {} of String => VersionEntry)
    end

    def self.load(fsdd_docs_dir : String) : VersionRamp
      versions_path = File.join(fsdd_docs_dir, "versions.json")
      versions = if File.exists?(versions_path)
        JSON.parse(File.read(versions_path)).as_a.map(&.as_s)
      else
        [] of String
      end

      return empty if versions.empty?

      all_keys = Hash(String, Array(String)).new

      versions.each do |v|
        json_path = File.join(fsdd_docs_dir, "json", v, "index.json")
        next unless File.exists?(json_path)

        types = Parser.parse_file(json_path)
        types.each do |t|
          type_key = t.full_name
          (all_keys[type_key] ||= [] of String) << v

          t.methods.each do |m|
            sep = m.is_class_method ? "." : "#"
            method_key = "#{t.full_name}#{sep}#{m.name}"
            (all_keys[method_key] ||= [] of String) << v
          end
        end
      end

      entries = all_keys.transform_values { |vs| VersionEntry.new(vs.first? || "", vs) }
      new(versions, entries)
    end

    def ramp_for(key : String) : VersionEntry?
      entries[key]?
    end

    def first_appeared(key : String) : String?
      entries[key]?.try(&.first_version)
    end

    # Returns ↑ if newly added in current_version, ↓ if removed, "" otherwise.
    def ramp_symbol(key : String, current_version : String?) : String
      return "" unless current_version
      entry = entries[key]?
      return "" unless entry

      current_idx = versions.index(current_version)
      return "" unless current_idx

      is_in_current = entry.present_in?(current_version)

      if current_idx > 0
        prev_version = versions[current_idx - 1]
        is_in_prev = entry.present_in?(prev_version)

        if is_in_current && !is_in_prev
          "↑"
        elsif !is_in_current && is_in_prev
          "↓"
        else
          ""
        end
      else
        ""
      end
    end

    # Human-readable "Since: v1.0" label for a key.
    def since_label(key : String) : String?
      entry = entries[key]?
      return nil unless entry
      "v#{entry.first_version}"
    end
  end
end
