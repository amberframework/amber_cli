require "semantic_version"
require "json"
require "yaml"

require "./source_models"

module AmberLSP::Lookup
  struct APICardNote
    include YAML::Serializable
    include JSON::Serializable

    getter symbol : String
    getter text : String
  end

  struct APICardErrorHint
    include YAML::Serializable
    include JSON::Serializable

    getter pattern : String
    getter hint : String
    getter example : String
  end

  struct APICard
    include YAML::Serializable

    getter card_version : Int32
    getter library : String
    getter applies_to : String
    getter docs_flags : Array(String) = [] of String
    getter docs_entries : Array(String) = [] of String
    getter notes : Array(APICardNote) = [] of APICardNote
    getter error_hints : Array(APICardErrorHint) = [] of APICardErrorHint
  end

  struct LoadedAPICard
    getter card : APICard
    getter source_path : String
    getter resolved_version : String

    def initialize(@card : APICard, @source_path : String, @resolved_version : String)
    end
  end

  # :nodoc:
  struct APICardErrorHintMatch
    getter card_library : String
    getter card_version : String
    getter error_hint : APICardErrorHint

    def initialize(@card_library : String, @card_version : String, @error_hint : APICardErrorHint)
    end
  end

  struct APICardCollection
    getter list_of_cards : Array(LoadedAPICard)
    getter list_of_errors : Array(String)

    def initialize(@list_of_cards : Array(LoadedAPICard), @list_of_errors : Array(String))
    end

    def docs_flags_by_library : Hash(String, Array(String))
      list_of_cards = {} of String => Array(String)
      @list_of_cards.each do |loaded_card|
        list_of_cards[loaded_card.card.library] = loaded_card.card.docs_flags
      end
      list_of_cards
    end

    def docs_entries_by_library : Hash(String, Array(String))
      list_of_entries = {} of String => Array(String)
      @list_of_cards.each do |loaded_card|
        next if loaded_card.card.docs_entries.empty?

        list_of_entries[loaded_card.card.library] = loaded_card.card.docs_entries
      end
      list_of_entries
    end

    def matching_notes(query : String) : Array(APICardNote)
      query_method_name = query.split(/[.#]/).last?
      @list_of_cards.flat_map do |loaded_card|
        loaded_card.card.notes.select do |note|
          note.symbol == query || note.symbol == query_method_name
        end
      end
    end

    def matching_error_hints(error_text : String) : Array(APICardErrorHint)
      matching_error_hint_matches(error_text).map(&.error_hint)
    end

    def matching_error_hint_matches(error_text : String) : Array(APICardErrorHintMatch)
      @list_of_cards.flat_map do |loaded_card|
        loaded_card.card.error_hints.select do |hint|
          Regex.new(hint.pattern).matches?(error_text)
        end.map do |hint|
          APICardErrorHintMatch.new(loaded_card.card.library, loaded_card.resolved_version, hint)
        end
      end
    end
  end

  class APIVersionRequirement
    def initialize(@requirement : String)
    end

    def matches?(version_text : String) : Bool
      current_version = parse_version(version_text)
      return false unless current_version

      requirement = @requirement.strip
      return true if requirement.empty? || requirement == "*"

      requirement.split(',').all? do |clause|
        matches_clause?(current_version, clause.strip)
      end
    rescue ex : ArgumentError
      false
    end

    private def matches_clause?(current_version : SemanticVersion, clause : String) : Bool
      if match = clause.match(/\A(~>|>=|<=|!=|==|>|<|=)?\s*(\d+\.\d+(?:\.\d+)?(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)\z/)
        operator = match[1]? || "="
        requested_version = parse_version(match[2])
        return false unless requested_version

        case operator
        when "~>"
          upper_version = pessimistic_upper_bound(match[2], requested_version)
          current_version >= requested_version && current_version < upper_version
        when ">="
          current_version >= requested_version
        when "<="
          current_version <= requested_version
        when ">"
          current_version > requested_version
        when "<"
          current_version < requested_version
        when "!="
          current_version != requested_version
        else
          current_version == requested_version
        end
      else
        false
      end
    end

    private def parse_version(version_text : String) : SemanticVersion?
      normalized = normalize_version(version_text.strip)
      SemanticVersion.parse?(normalized)
    end

    private def normalize_version(version_text : String) : String
      version_without_metadata = version_text.split('+', 2).first || version_text
      version_core = version_without_metadata.split('-', 2).first || version_without_metadata
      component_count = version_core.split('.').size
      suffix = version_text[version_core.bytesize..]? || ""
      case component_count
      when 1
        "#{version_core}.0.0#{suffix}"
      when 2
        "#{version_core}.0#{suffix}"
      else
        version_text
      end
    end

    private def pessimistic_upper_bound(version_text : String, version : SemanticVersion) : SemanticVersion
      component_count = version_text.split(/[+-]/).first.to_s.split('.').size
      if component_count <= 2
        SemanticVersion.new(version.major + 1, 0, 0)
      else
        SemanticVersion.new(version.major, version.minor + 1, 0)
      end
    end
  end

  class LoadAPICards
    def initialize(@project_root_path : String)
      @project_root_path = File.expand_path(@project_root_path)
    end

    def perform : APICardCollection
      project_manifest = read_project_manifest
      list_of_targets = [CardSource.new(@project_root_path, project_manifest.name, project_manifest.version)]
      list_of_targets.concat(library_card_sources)

      list_of_cards = [] of LoadedAPICard
      list_of_errors = [] of String
      list_of_targets.each do |target|
        next if target.library_name.empty?

        card_paths(target.root_path).each do |path|
          begin
            card = APICard.from_yaml(File.read(path))
            validate_card(card, target, path)
            next unless APIVersionRequirement.new(card.applies_to).matches?(target.resolved_version)

            list_of_cards << LoadedAPICard.new(card, path, target.resolved_version)
          rescue ex : YAML::ParseException | IO::Error | ArgumentError
            list_of_errors << "#{path}: #{ex.message}"
          end
        end
      end

      duplicate_library_cards(list_of_cards).each do |library_name|
        list_of_errors << "More than one API card applies to #{library_name}"
        list_of_cards.reject! { |loaded_card| loaded_card.card.library == library_name }
      end

      APICardCollection.new(list_of_cards, list_of_errors)
    rescue ex : YAML::ParseException | IO::Error
      APICardCollection.new([] of LoadedAPICard, [ex.message || "Could not load API cards"])
    end

    private def read_project_manifest : ProjectShardManifest
      manifest_path = File.join(@project_root_path, "shard.yml")
      return ProjectShardManifest.new unless File.file?(manifest_path)

      ProjectShardManifest.from_yaml(File.read(manifest_path))
    end

    private def library_card_sources : Array(CardSource)
      lock_path = File.join(@project_root_path, "shard.lock")
      return [] of CardSource unless File.file?(lock_path)

      lockfile = ShardLockfile.from_yaml(File.read(lock_path))
      lockfile.shards.to_a.sort_by(&.first).compact_map do |library_name, locked_shard|
        library_root = File.join(@project_root_path, "lib", library_name)
        next unless File.directory?(library_root)

        CardSource.new(library_root, library_name, locked_shard.version)
      end
    end

    private def card_paths(root_path : String) : Array(String)
      Dir.glob(File.join(root_path, ".amber-lsp", "api", "*.yml")).sort
    end

    private def validate_card(card : APICard, target : CardSource, path : String) : Nil
      raise ArgumentError.new("card_version must be 1") unless card.card_version == 1
      raise ArgumentError.new("library must be #{target.library_name}") unless card.library == target.library_name
      raise ArgumentError.new("applies_to must be a supported semantic version requirement") unless valid_requirement?(card.applies_to)

      card.docs_flags.each do |flag|
        raise ArgumentError.new("invalid docs flag #{flag.inspect}") unless flag.matches?(/\A[A-Za-z_][A-Za-z0-9_]*\z/)
      end

      card.docs_entries.each do |entry|
        path = Path[entry]
        raise ArgumentError.new("docs_entries paths must be relative to the shard root") if entry.empty? || path.absolute?
        raise ArgumentError.new("docs_entries paths cannot traverse outside the shard root") if entry.split(/[\\\/]/).includes?("..")
      end

      card.notes.each do |note|
        raise ArgumentError.new("each note needs a symbol and text") if note.symbol.empty? || note.text.empty?
      end

      card.error_hints.each do |hint|
        raise ArgumentError.new("each error hint needs a pattern, hint, and example") if hint.pattern.empty? || hint.hint.empty? || hint.example.empty?
        Regex.new(hint.pattern)
      end
    rescue ex : ArgumentError
      raise ArgumentError.new("#{path}: #{ex.message}")
    end

    private def valid_requirement?(requirement : String) : Bool
      return false if requirement.strip.empty?
      return true if requirement.strip == "*"

      requirement.split(',').all? do |clause|
        clause.strip.matches?(/\A(?:~>|>=|<=|!=|==|>|<|=)?\s*\d+\.\d+(?:\.\d+)?(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?\z/)
      end
    end

    private def duplicate_library_cards(cards : Array(LoadedAPICard)) : Array(String)
      cards.group_by(&.card.library).select { |_, list_of_cards| list_of_cards.size > 1 }.keys
    end

    private struct CardSource
      getter root_path : String
      getter library_name : String
      getter resolved_version : String

      def initialize(@root_path : String, @library_name : String, @resolved_version : String)
      end
    end
  end
end
