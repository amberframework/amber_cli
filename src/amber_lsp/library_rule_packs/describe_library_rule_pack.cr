require "yaml"

module AmberLSP::LibraryRulePacks
  class DescribeLibraryRulePack
    include YAML::Serializable

    @[YAML::Field(key: "pack")]
    property pack_id : String

    @[YAML::Field(key: "library")]
    property library_shard_name : String

    @[YAML::Field(key: "version")]
    property pack_version : String

    @[YAML::Field(key: "modes")]
    property modes_by_name : Hash(String, Mode) = {} of String => Mode

    @[YAML::Field(key: "rules")]
    property list_of_rules : Array(Rule) = [] of Rule

    def is_valid? : Bool
      return false if @pack_id.empty? || @library_shard_name.empty? || @pack_version.empty?
      return false if @modes_by_name.empty?

      @list_of_rules.all? do |rule|
        !rule.rule_id.empty? &&
          !rule.list_of_mode_names.empty? &&
          rule.list_of_mode_names.all? { |mode_name| @modes_by_name.has_key?(mode_name) } &&
          !rule.list_of_applicable_globs.empty? &&
          !rule.check.check_kind.empty?
      end
    end

    class Mode
      include YAML::Serializable

      @[YAML::Field(key: "context")]
      property guidance_text : String = ""
    end

    class Rule
      include YAML::Serializable

      @[YAML::Field(key: "id")]
      property rule_id : String

      @[YAML::Field(key: "modes")]
      property list_of_mode_names : Array(String) = [] of String

      @[YAML::Field(key: "severity")]
      property severity_name : String = "warning"

      @[YAML::Field(key: "applies_to")]
      property list_of_applicable_globs : Array(String) = ["**/*.cr"]

      @[YAML::Field(key: "exclude_from")]
      property list_of_excluded_globs : Array(String) = [] of String

      @[YAML::Field(key: "message")]
      property diagnostic_message : String = ""

      property check : Check
    end

    class Check
      include YAML::Serializable

      @[YAML::Field(key: "kind")]
      property check_kind : String

      @[YAML::Field(key: "pattern")]
      property regex_pattern : String = ""

      @[YAML::Field(key: "trigger_pattern")]
      property trigger_regex_pattern : String = ""

      @[YAML::Field(key: "required_pattern")]
      property required_regex_pattern : String = ""

      @[YAML::Field(key: "negate")]
      property? negates_pattern : Bool = false

      @[YAML::Field(key: "source_globs")]
      property list_of_source_globs : Array(String) = [] of String

      @[YAML::Field(key: "tenant_macro")]
      property model_macro_name : String = "multitenant"

      @[YAML::Field(key: "methods")]
      property list_of_query_method_names : Array(String) = [] of String

      @[YAML::Field(key: "required_call")]
      property required_block_call_name : String = ""

      @[YAML::Field(key: "escape_call")]
      property escape_block_call_name : String = ""

      @[YAML::Field(key: "condition")]
      property project_condition : String = "mixed_modes"

      @[YAML::Field(key: "operation")]
      property operation_name : String = ""
    end
  end
end
