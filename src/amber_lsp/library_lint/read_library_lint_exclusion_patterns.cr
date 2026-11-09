require "yaml"

module AmberLSP::LibraryLint
  # Reads check-command exclusion patterns while preserving editor configuration behavior.
  class ReadLibraryLintExclusionPatterns
    # Initializes the reader with *root_path* and existing Amber LSP exclusions.
    def initialize(
      @root_path : String,
      @list_of_default_exclusion_patterns : Array(String),
    )
    end

    # Reads `exclude_patterns` or returns the existing `exclude` patterns.
    def perform : AmberLSP::Rules::Library::Support::ListOfStrings
      configuration_path = File.join(@root_path, AmberLSP::Configuration::CONFIG_FILE_NAME)
      return @list_of_default_exclusion_patterns unless File.file?(configuration_path)

      yaml_document = YAML.parse(File.read(configuration_path))
      exclusion_node = yaml_document["exclude_patterns"]?
      return @list_of_default_exclusion_patterns unless exclusion_node

      exclusion_node.as_a.map(&.as_s)
    end
  end
end
