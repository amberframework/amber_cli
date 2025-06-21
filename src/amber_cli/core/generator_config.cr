require "json"
require "yaml"

module AmberCLI::Core
  struct FileGenerationRule
    getter template : String
    getter output_path : String
    getter transformations : Hash(String, String)?
    getter conditions : Hash(String, String)?

    def initialize(@template : String, @output_path : String, @transformations : Hash(String, String)?, @conditions : Hash(String, String)?)
    end

    def template_file_path(template_dir : String) : String
      File.join(template_dir, "#{template}.amber-template")
    end
  end

  class GeneratorConfig
    getter name : String
    getter description : String?
    getter template_variables : Hash(String, String)?
    getter naming_conventions : Hash(String, String)?
    getter file_generation_rules : Hash(String, Array(FileGenerationRule))?
    getter post_generation_commands : Array(String)?
    getter dependencies : Array(String)?

    def initialize(@name : String, @description : String? = nil, @template_variables : Hash(String, String)? = nil, 
                   @naming_conventions : Hash(String, String)? = nil, @file_generation_rules : Hash(String, Array(FileGenerationRule))? = nil,
                   @post_generation_commands : Array(String)? = nil, @dependencies : Array(String)? = nil)
    end

    def self.load_from_file(file_path : String) : GeneratorConfig?
      return nil unless File.exists?(file_path)
      
      begin
        content = File.read(file_path)
        case File.extname(file_path)
        when ".json"
          load_from_json(content)
        when ".yml", ".yaml"
          load_from_yaml(content)
        else
          nil
        end
      rescue
        nil
      end
    end

    private def self.load_from_json(content : String) : GeneratorConfig?
      begin
        data = JSON.parse(content)
        parse_json_config_data(data)
      rescue
        nil
      end
    end

    private def self.load_from_yaml(content : String) : GeneratorConfig?
      begin
        data = YAML.parse(content)
        parse_yaml_config_data(data)
      rescue
        nil
      end
    end

    private def self.parse_json_config_data(data : JSON::Any) : GeneratorConfig?
      name = data["name"]?.try(&.as_s?)
      return nil unless name

      description = data["description"]?.try(&.as_s?)
      
      # Parse template variables
      template_variables = nil
      if tv_data = data["template_variables"]?
        template_variables = Hash(String, String).new
        tv_data.as_h?.try &.each do |key, value|
          if value_str = value.as_s?
            template_variables[key] = value_str
          elsif value_i = value.as_i?
            template_variables[key] = value_i.to_s
          elsif value_b = value.as_bool?
            template_variables[key] = value_b.to_s
          end
        end
      end
      
      # Parse naming conventions
      naming_conventions = nil
      if nc_data = data["naming_conventions"]?
        naming_conventions = Hash(String, String).new
        nc_data.as_h?.try &.each do |key, value|
          if value_str = value.as_s?
            naming_conventions[key] = value_str
          end
        end
      end
      
      dependencies = data["dependencies"]?.try { |d| d.as_a?.try(&.map(&.as_s)) }
      post_commands = data["post_generation_commands"]?.try { |d| d.as_a?.try(&.map(&.as_s)) }

      # Parse file generation rules
      rules = parse_json_file_generation_rules(data["file_generation_rules"]?)

      GeneratorConfig.new(name, description, template_variables, naming_conventions, rules, post_commands, dependencies)
    end

    private def self.parse_yaml_config_data(data : YAML::Any) : GeneratorConfig?
      name = data["name"]?.try(&.as_s?)
      return nil unless name

      description = data["description"]?.try(&.as_s?)
      
      # Parse template variables
      template_variables = nil
      if tv_data = data["template_variables"]?
        template_variables = Hash(String, String).new
        tv_data.as_h?.try &.each do |key, value|
          if value_str = value.as_s?
            template_variables[key.as_s] = value_str
          elsif value_i = value.as_i?
            template_variables[key.as_s] = value_i.to_s
          elsif value_b = value.as_bool?
            template_variables[key.as_s] = value_b.to_s
          end
        end
      end
      
      # Parse naming conventions
      naming_conventions = nil
      if nc_data = data["naming_conventions"]?
        naming_conventions = Hash(String, String).new
        nc_data.as_h?.try &.each do |key, value|
          if value_str = value.as_s?
            naming_conventions[key.as_s] = value_str
          end
        end
      end
      
      dependencies = data["dependencies"]?.try { |d| d.as_a?.try(&.map(&.as_s)) }
      post_commands = data["post_generation_commands"]?.try { |d| d.as_a?.try(&.map(&.as_s)) }

      # Parse file generation rules
      rules = parse_yaml_file_generation_rules(data["file_generation_rules"]?)

      GeneratorConfig.new(name, description, template_variables, naming_conventions, rules, post_commands, dependencies)
    end

    private def self.parse_json_file_generation_rules(rules_data : JSON::Any?) : Hash(String, Array(FileGenerationRule))?
      return nil unless rules_data
      
      rules = Hash(String, Array(FileGenerationRule)).new
      rules_data.as_h?.try &.each do |generator_type, generator_rules|
        rule_array = Array(FileGenerationRule).new
        generator_rules.as_a?.try &.each do |rule_data|
          if template = rule_data["template"]?.try(&.as_s?)
            output_path = rule_data["output_path"]?.try(&.as_s?) || ""
            transformations = parse_json_transformations(rule_data["transformations"]?)
            conditions = parse_json_conditions(rule_data["conditions"]?)
            rule_array << FileGenerationRule.new(template, output_path, transformations, conditions)
          end
        end
        rules[generator_type] = rule_array
      end
      rules
    end

    private def self.parse_yaml_file_generation_rules(rules_data : YAML::Any?) : Hash(String, Array(FileGenerationRule))?
      return nil unless rules_data
      
      rules = Hash(String, Array(FileGenerationRule)).new
      rules_data.as_h?.try &.each do |generator_type, generator_rules|
        rule_array = Array(FileGenerationRule).new
        generator_rules.as_a?.try &.each do |rule_data|
          if template = rule_data["template"]?.try(&.as_s?)
            output_path = rule_data["output_path"]?.try(&.as_s?) || ""
            transformations = parse_yaml_transformations(rule_data["transformations"]?)
            conditions = parse_yaml_conditions(rule_data["conditions"]?)
            rule_array << FileGenerationRule.new(template, output_path, transformations, conditions)
          end
        end
        rules[generator_type.as_s] = rule_array
      end
      rules
    end

    private def self.parse_json_transformations(data : JSON::Any?) : Hash(String, String)?
      return nil unless data
      
      result = Hash(String, String).new
      data.as_h?.try &.each { |k, v| result[k] = v.as_s? || "" }
      result
    end

    private def self.parse_yaml_transformations(data : YAML::Any?) : Hash(String, String)?
      return nil unless data
      
      result = Hash(String, String).new
      data.as_h?.try &.each { |k, v| result[k.as_s] = v.as_s? || "" }
      result
    end

    private def self.parse_json_conditions(data : JSON::Any?) : Hash(String, String)?
      return nil unless data
      
      result = Hash(String, String).new
      data.as_h?.try &.each { |k, v| result[k] = v.as_s? || "" }
      result
    end

    private def self.parse_yaml_conditions(data : YAML::Any?) : Hash(String, String)?
      return nil unless data
      
      result = Hash(String, String).new
      data.as_h?.try &.each { |k, v| result[k.as_s] = v.as_s? || "" }
      result
    end

    def template_variables_as_hash : Hash(String, String)
      template_variables || Hash(String, String).new
    end

    def naming_conventions_hash : Hash(String, String)
      naming_conventions || Hash(String, String).new
    end
  end
end 