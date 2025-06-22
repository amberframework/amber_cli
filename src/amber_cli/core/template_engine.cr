# :nodoc:
require "ecr"
require "file_utils"
require "../exceptions"
require "./word_transformer"
require "./generator_config"

module AmberCLI::Core
  class TemplateEngine
    def initialize
    end

    def process_template(template_content : String, replacements : Hash(String, String), strict : Bool = false) : String
      result = template_content

      # Replace all placeholders
      replacements.each do |key, value|
        result = result.gsub("{{#{key}}}", value)
      end

      # Check for remaining placeholders in strict mode
      if strict && result.includes?("{{")
        remaining = result.scan(/\{\{([^}]+)\}\}/).map(&.[1])
        raise AmberCLI::Exceptions::TemplateError.new("Unknown placeholder: #{remaining.join(", ")}")
      end

      result
    end

    def generate_file_from_rule(rule : FileGenerationRule, word : String, template_dir : String, custom_variables : Hash(String, String), naming_conventions : Hash(String, String) = {} of String => String, amber_framework_version : String = "1.4.0") : Array(NamedTuple(path: String, content: String))
      # Check conditions first
      if conditions = rule.conditions
        return [] of NamedTuple(path: String, content: String) unless meets_conditions?(conditions, custom_variables)
      end

      # Load template file
      template_path = rule.template_file_path(template_dir)
      unless File.exists?(template_path)
        raise AmberCLI::Exceptions::TemplateError.new("Template file not found: #{template_path}")
      end

      template_content = File.read(template_path)

      # Build replacement context
      replacements = custom_variables.dup

              # Add built-in variables
        replacements["cli_version"] = AmberCli::VERSION
        replacements["amber_framework_version"] = amber_framework_version

      # Add word transformations
      if transformations = rule.transformations
        transformations.each do |placeholder, transformation|
          replacements[placeholder] = WordTransformer.transform(word, transformation, naming_conventions)
        end
      end

      # Add basic transformations
      replacements["snake_case"] = WordTransformer.transform(word, "snake_case", naming_conventions)
      replacements["pascal_case"] = WordTransformer.transform(word, "pascal_case", naming_conventions)
      replacements["snake_case_plural"] = WordTransformer.transform(word, "snake_case_plural", naming_conventions)
      replacements["pascal_case_plural"] = WordTransformer.transform(word, "pascal_case_plural", naming_conventions)

      # Process template
      processed_content = process_template(template_content, replacements)

      # Process output path
      output_path = process_template(rule.output_path, replacements)

      [{path: output_path, content: processed_content}]
    end

    private def meets_conditions?(conditions : Hash(String, String), context : Hash(String, String)) : Bool
      conditions.all? do |key, expected_value|
        context[key]? == expected_value
      end
    end
  end
end
