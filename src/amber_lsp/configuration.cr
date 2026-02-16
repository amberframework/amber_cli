require "yaml"

module AmberLSP
  class Configuration
    DEFAULT_EXCLUDE_PATTERNS = ["lib/", "tmp/", "db/migrations/"]
    CONFIG_FILE_NAME         = ".amber-lsp.yml"

    struct RuleConfig
      getter enabled : Bool
      getter severity : Rules::Severity?

      def initialize(@enabled : Bool = true, @severity : Rules::Severity? = nil)
      end
    end

    struct CustomRuleConfig
      getter id : String
      getter description : String
      getter severity : String
      getter applies_to : Array(String)
      getter pattern : String
      getter message : String
      getter? negate : Bool

      def initialize(
        @id : String,
        @description : String,
        @severity : String = "warning",
        @applies_to : Array(String) = ["src/**"],
        @pattern : String = "",
        @message : String = "",
        @negate : Bool = false,
      )
      end
    end

    getter exclude_patterns : Array(String)
    getter custom_rules : Array(CustomRuleConfig)

    def initialize(
      @rule_configs : Hash(String, RuleConfig) = Hash(String, RuleConfig).new,
      @exclude_patterns : Array(String) = DEFAULT_EXCLUDE_PATTERNS.dup,
      @custom_rules : Array(CustomRuleConfig) = [] of CustomRuleConfig,
    )
    end

    def self.load(project_root : String) : Configuration
      config_path = File.join(project_root, CONFIG_FILE_NAME)

      if File.exists?(config_path)
        parse(File.read(config_path))
      else
        Configuration.new
      end
    end

    def self.parse(yaml_content : String) : Configuration
      yaml = YAML.parse(yaml_content)

      rule_configs = Hash(String, RuleConfig).new
      if rules_node = yaml["rules"]?
        rules_node.as_h.each do |key, value|
          enabled = true
          severity = nil

          if value_hash = value.as_h?
            if enabled_val = value_hash["enabled"]?
              enabled = enabled_val.as_bool
            end
            if severity_val = value_hash["severity"]?
              severity = parse_severity(severity_val.as_s)
            end
          end

          rule_configs[key.as_s] = RuleConfig.new(enabled: enabled, severity: severity)
        end
      end

      exclude_patterns = DEFAULT_EXCLUDE_PATTERNS.dup
      if exclude_node = yaml["exclude"]?
        exclude_patterns = exclude_node.as_a.map(&.as_s)
      end

      custom_rules = [] of CustomRuleConfig
      if custom_rules_node = yaml["custom_rules"]?
        custom_rules_node.as_a.each do |rule_node|
          rule_hash = rule_node.as_h
          next unless rule_hash["id"]? && rule_hash["pattern"]?

          id = rule_hash["id"].as_s
          description = rule_hash["description"]?.try(&.as_s) || ""
          severity = rule_hash["severity"]?.try(&.as_s) || "warning"
          pattern = rule_hash["pattern"].as_s
          message = rule_hash["message"]?.try(&.as_s) || ""
          negate = rule_hash["negate"]?.try(&.as_bool) || false

          applies_to = ["src/**"]
          if applies_node = rule_hash["applies_to"]?
            applies_to = applies_node.as_a.map(&.as_s)
          end

          custom_rules << CustomRuleConfig.new(
            id: id,
            description: description,
            severity: severity,
            applies_to: applies_to,
            pattern: pattern,
            message: message,
            negate: negate,
          )
        end
      end

      Configuration.new(
        rule_configs: rule_configs,
        exclude_patterns: exclude_patterns,
        custom_rules: custom_rules,
      )
    rescue YAML::ParseException
      Configuration.new
    end

    def rule_enabled?(id : String) : Bool
      if config = @rule_configs[id]?
        config.enabled
      else
        true
      end
    end

    def rule_severity(id : String, default : Rules::Severity) : Rules::Severity
      if config = @rule_configs[id]?
        config.severity || default
      else
        default
      end
    end

    def excluded?(file_path : String) : Bool
      @exclude_patterns.any? { |pattern| file_path.includes?(pattern) }
    end

    private def self.parse_severity(value : String) : Rules::Severity?
      case value.downcase
      when "error"       then Rules::Severity::Error
      when "warning"     then Rules::Severity::Warning
      when "information" then Rules::Severity::Information
      when "hint"        then Rules::Severity::Hint
      else                    nil
      end
    end
  end
end
