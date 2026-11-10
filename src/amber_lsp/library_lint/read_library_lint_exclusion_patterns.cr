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
      return @list_of_default_exclusion_patterns unless configuration_mapping = yaml_document.as_h?

      exclusion_node = configuration_mapping[YAML::Any.new("exclude_patterns")]?
      return @list_of_default_exclusion_patterns unless exclusion_node

      read_list_of_patterns(exclusion_node)
    end

    private def read_list_of_patterns(
      exclusion_node : YAML::Any,
    ) : AmberLSP::Rules::Library::Support::ListOfStrings
      list_of_nodes = exclusion_node.as_a?
      raise InvalidArguments.new("exclude_patterns in .amber-lsp.yml must be a list of strings") unless list_of_nodes

      list_of_nodes.map do |pattern_node|
        pattern = pattern_node.as_s?
        raise InvalidArguments.new("exclude_patterns in .amber-lsp.yml must be a list of strings") unless pattern

        pattern
      end
    end
  end
end
