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
    getter template_variables : JSON::Any?
    getter naming_conventions : JSON::Any?
    getter file_generation_rules : Hash(String, Array(FileGenerationRule))?
    getter post_generation_commands : Array(String)?
    getter dependencies : Array(String)?

    def initialize(@name : String, @description : String? = nil, @template_variables : JSON::Any? = nil, 
                   @naming_conventions : JSON::Any? = nil, @file_generation_rules : Hash(String, Array(FileGenerationRule))? = nil,
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
        parse_config_data(data)
      rescue
        nil
      end
    end

    private def self.load_from_yaml(content : String) : GeneratorConfig?
      begin
        data = YAML.parse(content)
        parse_config_data(data)
      rescue
        nil
      end
    end

    private def self.parse_config_data(data : JSON::Any | YAML::Any) : GeneratorConfig?
      name = data["name"]?.try(&.as_s?)
      return nil unless name

      description = data["description"]?.try(&.as_s?)
      template_variables = data["template_variables"]?.as(JSON::Any?)
      naming_conventions = data["naming_conventions"]?.as(JSON::Any?)
      dependencies = data["dependencies"]?.try { |d| d.as_a?.try(&.map(&.as_s)) }
      post_commands = data["post_generation_commands"]?.try { |d| d.as_a?.try(&.map(&.as_s)) }

      # Parse file generation rules
      rules = nil
      if rules_data = data["file_generation_rules"]?
        rules = Hash(String, Array(FileGenerationRule)).new
        rules_data.as_h?.try &.each do |generator_type, generator_rules|
          rule_array = Array(FileGenerationRule).new
          generator_rules.as_a?.try &.each do |rule_data|
            if template = rule_data["template"]?.try(&.as_s?)
              output_path = rule_data["output_path"]?.try(&.as_s?) || ""
              transformations = rule_data["transformations"]?.try { |t| 
                result = Hash(String, String).new
                t.as_h?.try &.each { |k, v| 
                  key_str = k.is_a?(String) ? k : k.as_s? || ""
                  result[key_str] = v.as_s? || "" 
                }
                result
              }
              conditions = rule_data["conditions"]?.try { |c|
                result = Hash(String, String).new
                c.as_h?.try &.each { |k, v| 
                  key_str = k.is_a?(String) ? k : k.as_s? || ""
                  result[key_str] = v.as_s? || "" 
                }
                result
              }
              rule_array << FileGenerationRule.new(template, output_path, transformations, conditions)
            end
          end
          generator_type_str = generator_type.is_a?(String) ? generator_type : generator_type.as_s? || ""
          rules[generator_type_str] = rule_array
        end
      end

      GeneratorConfig.new(name, description, template_variables, naming_conventions, rules, post_commands, dependencies)
    end

    def template_variables_as_hash : Hash(String, String)
      result = Hash(String, String).new
      if tv = template_variables
        tv.as_h?.try &.each do |key, value|
          if value_str = value.as_s?
            result[key] = value_str
          elsif value_i = value.as_i?
            result[key] = value_i.to_s
          elsif value_b = value.as_bool?
            result[key] = value_b.to_s
          end
        end
      end
      result
    end

    def naming_conventions_hash : Hash(String, String)
      result = Hash(String, String).new
      if nc = naming_conventions
        nc.as_h?.try &.each do |key, value|
          if value_str = value.as_s?
            result[key] = value_str
          end
        end
      end
      result
    end
  end
end 