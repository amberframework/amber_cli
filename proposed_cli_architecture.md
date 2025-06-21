# Proposed Amber CLI Architecture - Standard Library Only

> **Goal**: Restructure the Amber CLI to use only Crystal's standard library, eliminating external dependencies while maintaining full functionality.

## Core Architecture Overview

### 1. Command System Architecture

Replace the current `::Cli::Supercommand` system with a clean, native Crystal approach using `OptionParser`.

```crystal
# src/amber_cli/core/base_command.cr
module AmberCLI::Core
  abstract class BaseCommand
    getter option_parser : OptionParser
    getter parsed_options : Hash(String, String | Bool | Array(String))
    getter remaining_arguments : Array(String)

    def initialize(@command_name : String)
      @option_parser = OptionParser.new
      @parsed_options = Hash(String, String | Bool | Array(String)).new
      @remaining_arguments = Array(String).new
      setup_global_options
      setup_command_options
    end

    abstract def setup_command_options
    abstract def execute
    abstract def help_description : String

    private def setup_global_options
      option_parser.banner = help_description
      option_parser.on("--no-color", "Disable colored output") do
        @parsed_options["no_color"] = true
      end
      option_parser.on("-h", "--help", "Show help") do
        puts option_parser
        exit(0)
      end
    end

    def parse_and_execute(args : Array(String))
      option_parser.unknown_args do |unknown_args, _|
        @remaining_arguments.concat(unknown_args)
      end
      
      option_parser.parse(args)
      validate_arguments
      execute
    rescue ex : OptionParser::InvalidOption
      error "Invalid option: #{ex.message}"
      puts option_parser
      exit(1)
    end

    protected def validate_arguments
      # Override in subclasses for specific validation
    end

    protected def error(message : String)
      puts "Error: #{message}".colorize.red
    end

    protected def info(message : String)
      puts message.colorize.light_cyan
    end

    protected def success(message : String)
      puts message.colorize.green
    end
  end
end
```

### 2. Command Registry System

```crystal
# src/amber_cli/core/command_registry.cr
module AmberCLI::Core
  class CommandRegistry
    COMMANDS = Hash(String, BaseCommand.class).new

    def self.register(name : String, aliases : Array(String), command_class : BaseCommand.class)
      COMMANDS[name] = command_class
      aliases.each { |alias_name| COMMANDS[alias_name] = command_class }
    end

    def self.find_command(name : String) : BaseCommand.class?
      COMMANDS[name]?
    end

    def self.list_commands : Array(String)
      COMMANDS.keys.uniq
    end

    def self.execute_command(command_name : String, args : Array(String))
      if command_class = find_command(command_name)
        command = command_class.new(command_name)
        command.parse_and_execute(args)
      else
        puts "Unknown command: #{command_name}"
        show_help
        exit(1)
      end
    end

    private def self.show_help
      puts <<-HELP
      Amber CLI - Crystal web framework tool

      Available commands:
      #{list_commands.join(", ")}

      Use 'amber <command> --help' for more information about a command.
      HELP
    end
  end
end
```

### 3. Configuration System for Customizable Generators

```crystal
# src/amber_cli/core/generator_config.cr
require "json"
require "yaml"

module AmberCLI::Core
  # Represents a file generation rule with template and transformation settings
  struct FileGenerationRule
    JSON.mapping(
      template: String,
      output_path: String,
      transformations: Hash(String, String)?,
      conditions: Hash(String, String)?
    )

    YAML.mapping(
      template: String,
      output_path: String,
      transformations: Hash(String, String)?,
      conditions: Hash(String, String)?
    )

    def template_file_path(template_dir : String) : String
      File.join(template_dir, "#{template}.amber-template")
    end
  end

  # Represents a generator configuration loaded from JSON/YAML
  class GeneratorConfig
    JSON.mapping(
      name: String,
      description: String?,
      template_variables: Hash(String, JSON::Any)?,
      custom_templates: Hash(String, String)?,
      file_generation_rules: Hash(String, Array(FileGenerationRule))?,
      naming_conventions: Hash(String, String)?,
      post_generation_commands: Array(String)?,
      dependencies: Array(String)?
    )

    YAML.mapping(
      name: String,
      description: String?,
      template_variables: Hash(String, YAML::Any)?,
      custom_templates: Hash(String, String)?,
      file_generation_rules: Hash(String, Array(FileGenerationRule))?,
      naming_conventions: Hash(String, String)?,
      post_generation_commands: Array(String)?,
      dependencies: Array(String)?
    )

    def self.load_from_file(file_path : String) : GeneratorConfig?
      return nil unless File.exists?(file_path)

      content = File.read(file_path)
      
      case File.extname(file_path).downcase
      when ".json"
        from_json(content)
      when ".yml", ".yaml"
        from_yaml(content)
      else
        raise "Unsupported configuration file format: #{file_path}"
      end
    rescue ex
      puts "Error loading generator config from #{file_path}: #{ex.message}".colorize.red
      nil
    end

    def template_variables_as_hash : Hash(String, String)
      result = Hash(String, String).new
      
      if vars = template_variables
        vars.each do |key, value|
          case value
          when JSON::Any
            result[key] = value.as_s? || value.to_s
          when YAML::Any
            result[key] = value.as_s? || value.to_s
          else
            result[key] = value.to_s
          end
        end
      end
      
      result
    end

    def naming_conventions_hash : Hash(String, String)
      naming_conventions || Hash(String, String).new
    end
  end

  # Manages loading and applying generator configurations
  class ConfigurableGeneratorManager
    CONFIG_FILENAMES = [".amber-generators.json", ".amber-generators.yml", ".amber-generators.yaml"]
    
    def self.find_config_in_project : GeneratorConfig?
      CONFIG_FILENAMES.each do |filename|
        if File.exists?(filename)
          return GeneratorConfig.load_from_file(filename)
        end
      end
      nil
    end

    def self.find_custom_template_dir : String?
      %w[.amber/templates amber/templates templates].each do |dir|
        return dir if Dir.exists?(dir)
      end
      nil
    end

    def self.has_custom_generator?(generator_type : String) : Bool
      return false unless config = find_config_in_project
      return false unless rules = config.file_generation_rules
      rules.has_key?(generator_type)
    end

    def self.get_generation_rules(generator_type : String) : Array(FileGenerationRule)?
      return nil unless config = find_config_in_project
      return nil unless rules = config.file_generation_rules
      rules[generator_type]?
    end
  end

  # Handles word transformations based on conventions
  class WordTransformer
    TRANSFORMATION_TYPES = {
      "singular" => ->(word : String) { singularize(word) },
      "plural" => ->(word : String) { pluralize(word) },
      "camel_case" => ->(word : String) { word.camelcase },
      "pascal_case" => ->(word : String) { word.camelcase },
      "snake_case" => ->(word : String) { word.underscore },
      "kebab_case" => ->(word : String) { word.underscore.gsub("_", "-") },
      "title_case" => ->(word : String) { word.split("_").map(&.capitalize).join(" ") },
      "upper_case" => ->(word : String) { word.upcase },
      "lower_case" => ->(word : String) { word.downcase },
      "constant_case" => ->(word : String) { word.underscore.upcase }
    }

    def self.transform(word : String, transformation : String, conventions : Hash(String, String) = Hash(String, String).new) : String
      # Check for custom convention first
      if custom_transform = conventions[transformation]?
        apply_custom_transformation(word, custom_transform)
      elsif transform_proc = TRANSFORMATION_TYPES[transformation]?
        transform_proc.call(word)
      else
        word # Return unchanged if transformation not found
      end
    end

    private def self.apply_custom_transformation(word : String, pattern : String) : String
      # Pattern can include things like "{{word}}_controller" or "I{{word}}Repository"
      pattern.gsub("{{word}}", word)
    end

    private def self.pluralize(word : String) : String
      # Enhanced pluralization logic
      case word.downcase
      when .ends_with?("y")
        if %w[a e i o u].includes?(word[-2].to_s.downcase)
          word + "s"
        else
          word[0..-2] + "ies"
        end
      when .ends_with?("s"), .ends_with?("ss"), .ends_with?("sh"), .ends_with?("ch"), .ends_with?("x"), .ends_with?("z")
        word + "es"
      when .ends_with?("f")
        word[0..-2] + "ves"
      when .ends_with?("fe")
        word[0..-3] + "ves"
      when .ends_with?("o")
        word + "es"  # This is simplified, real pluralization is more complex
      else
        word + "s"
      end
    end

    private def self.singularize(word : String) : String
      # Basic singularization (can be enhanced)
      case word.downcase
      when .ends_with?("ies")
        word[0..-4] + "y"
      when .ends_with?("ves")
        if word.ends_with?("ives")
          word[0..-4] + "ife"
        else
          word[0..-4] + "f"
        end
      when .ends_with?("ses"), .ends_with?("ches"), .ends_with?("shes"), .ends_with?("xes")
        word[0..-3]
      when .ends_with?("s") && !word.ends_with?("ss")
        word[0..-2]
      else
        word
      end
    end
  end
end
```

### 4. Enhanced Template Engine with Rule-Based Generation

```crystal
# src/amber_cli/core/template_engine.cr
module AmberCLI::Core
  class TemplateEngine
    getter template_variables : Hash(String, String)
    getter config : GeneratorConfig?
    getter base_name : String

    def initialize(@base_name : String, @template_variables = Hash(String, String).new, @config = nil)
      merge_config_variables if @config
      build_derived_variables
    end

    def render_from_generation_rules(generator_type : String, template_dir : String, output_dir : String, force : Bool = false)
      rules = ConfigurableGeneratorManager.get_generation_rules(generator_type)
      return unless rules

      rules.each do |rule|
        render_rule(rule, template_dir, output_dir, force)
      end
    end

    def render_template_file(template_path : String, output_path : String, force : Bool = false)
      unless File.exists?(template_path)
        raise "Template file not found: #{template_path}"
      end

      if File.exists?(output_path) && !force
        print "File #{output_path} already exists. Overwrite? (y/N): "
        response = gets
        return unless response && response.downcase.starts_with?("y")
      end

      template_content = File.read(template_path)
      rendered_content = process_template_content(template_content)
      
      ensure_directory_exists(output_path)
      File.write(output_path, rendered_content)
      puts "Created: #{output_path}".colorize.green
    end

    def render_template_string(template_content : String) : String
      process_template_content(template_content)
    end

    private def render_rule(rule : FileGenerationRule, template_dir : String, output_dir : String, force : Bool)
      # Check conditions first
      return unless conditions_met?(rule.conditions)

      template_path = rule.template_file_path(template_dir)
      unless File.exists?(template_path)
        puts "Warning: Template file not found: #{template_path}".colorize.yellow
        return
      end

      # Process output path with transformations
      output_path = process_output_path(rule.output_path, rule.transformations)
      full_output_path = File.join(output_dir, output_path)

      render_template_file(template_path, full_output_path, force)
    end

    private def conditions_met?(conditions : Hash(String, String)?) : Bool
      return true unless conditions

      conditions.each do |key, expected_value|
        actual_value = template_variables[key]? || ""
        return false unless actual_value == expected_value
      end
      true
    end

    private def process_output_path(path_pattern : String, transformations : Hash(String, String)?) : String
      result = path_pattern
      
      # Apply standard template variables first
      template_variables.each do |key, value|
        result = result.gsub("{{#{key}}}", value)
      end

      # Apply transformations if specified
      if transformations
        transformations.each do |placeholder, transformation|
          if result.includes?("{{#{placeholder}}}")
            transformed_value = WordTransformer.transform(@base_name, transformation, naming_conventions)
            result = result.gsub("{{#{placeholder}}}", transformed_value)
          end
        end
      end

      result
    end

    private def process_template_content(content : String) : String
      result = content
      
      # Apply all template variables
      template_variables.each do |key, value|
        result = result.gsub("{{#{key}}}", value)
        result = result.gsub("{%#{key}%}", value)
      end
      
      # Handle conditional blocks
      result = process_conditional_blocks(result)
      
      # Handle loops
      result = process_loop_blocks(result)
      
      result
    end

    private def build_derived_variables
      conventions = naming_conventions
      
      # Build all the standard transformations of the base name
      @template_variables.merge!({
        "name" => @base_name,
        "name_singular" => WordTransformer.transform(@base_name, "singular", conventions),
        "name_plural" => WordTransformer.transform(@base_name, "plural", conventions),
        "class_name" => WordTransformer.transform(@base_name, "pascal_case", conventions),
        "class_name_plural" => WordTransformer.transform(WordTransformer.transform(@base_name, "plural", conventions), "pascal_case", conventions),
        "snake_case" => WordTransformer.transform(@base_name, "snake_case", conventions),
        "snake_case_plural" => WordTransformer.transform(@base_name, "plural", conventions).underscore,
        "kebab_case" => WordTransformer.transform(@base_name, "kebab_case", conventions),
        "constant_name" => WordTransformer.transform(@base_name, "constant_case", conventions),
        "title_case" => WordTransformer.transform(@base_name, "title_case", conventions),
        "timestamp" => Time.utc.to_unix_ms.to_s
      })
    end

    private def naming_conventions : Hash(String, String)
      config = @config
      return Hash(String, String).new unless config
      config.naming_conventions_hash
    end

    private def merge_config_variables
      return unless config = @config
      config_vars = config.template_variables_as_hash
      @template_variables = config_vars.merge(@template_variables)
    end

    private def process_conditional_blocks(content : String) : String
      content.gsub(/\{\{#if\s+(\w+)\}\}(.*?)\{\{\/if\}\}/m) do |match|
        variable_name = $1
        block_content = $2
        
        if template_variables.has_key?(variable_name) && 
           !template_variables[variable_name].empty? && 
           template_variables[variable_name] != "false"
          process_template_content(block_content)
        else
          ""
        end
      end
    end

    private def process_loop_blocks(content : String) : String
      content.gsub(/\{\{#each\s+(\w+)\}\}(.*?)\{\{\/each\}\}/m) do |match|
        variable_name = $1
        block_content = $2
        
        if value = template_variables[variable_name]?
          items = value.split(",").map(&.strip)
          items.map { |item|
            block_content.gsub("{{this}}", item)
          }.join("\n")
        else
          ""
        end
      end
    end

    private def ensure_directory_exists(file_path : String)
      directory = File.dirname(file_path)
      Dir.mkdir_p(directory) unless Dir.exists?(directory)
    end
  end

  class TemplateGenerator
    def initialize(@name : String, @template_directory : String, @output_directory : String, @custom_config : GeneratorConfig? = nil)
      @config = @custom_config || ConfigurableGeneratorManager.find_config_in_project
      @template_engine = TemplateEngine.new(@name, build_template_variables, @config)
    end

    def generate(generator_type : String, force : Bool = false)
      # First, try to use custom generation rules from config
      if @config && ConfigurableGeneratorManager.has_custom_generator?(generator_type)
        @template_engine.render_from_generation_rules(generator_type, @template_directory, @output_directory, force)
      else
        # Fall back to standard template files
        generate_from_template_files(force)
      end

      # Run post-generation commands if specified
      run_post_generation_commands
      
      # Add dependencies if specified
      add_dependencies
    end

    private def generate_from_template_files(force : Bool)
      template_files.each do |template_file|
        relative_path = Path[template_file].relative_to(@template_directory)
        output_path = File.join(@output_directory, process_template_path(relative_path.to_s))
        @template_engine.render_template_file(template_file, output_path, force)
      end
    end

    private def run_post_generation_commands
      return unless config = @config
      return unless commands = config.post_generation_commands

      commands.each do |command|
        processed_command = @template_engine.render_template_string(command)
        puts "Running: #{processed_command}".colorize.yellow
        
        status = Process.run(processed_command, shell: true, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
        unless status.success?
          puts "Warning: Command failed: #{processed_command}".colorize.red
        end
      end
    end

    private def add_dependencies
      return unless config = @config
      return unless deps = config.dependencies

      puts "Adding dependencies: #{deps.join(", ")}".colorize.cyan
      # Implementation would depend on the project type (shard.yml, etc.)
    end

    private def template_files : Array(String)
      Dir.glob(File.join(@template_directory, "**", "*.amber-template"))
    end

    private def build_template_variables : Hash(String, String)
      base_vars = Hash(String, String).new

      # Add any additional variables from config
      if config = @config
        config_vars = config.template_variables_as_hash
        base_vars.merge(config_vars)
      else
        base_vars
      end
    end

    private def process_template_path(path : String) : String
      # Remove .amber-template extension and process placeholders
      processed_path = path.gsub(/\.amber-template$/, "")
      @template_engine.render_template_string(processed_path)
    end
  end
end
```

## 6. Enhanced Configuration Examples

### JSON Configuration with Template Rules

```json
{
  "name": "Enterprise Rails-like Conventions",
  "description": "Generators following Rails conventions with enterprise patterns",
  
  "template_variables": {
    "namespace": "MyCompany::ECommerce",
    "author": "Development Team",
    "use_audit_fields": "true",
    "database_timestamps": "true"
  },

  "naming_conventions": {
    "controller_suffix": "{{word}}Controller",
    "service_suffix": "{{word}}Service", 
    "repository_pattern": "{{word}}Repository",
    "interface_prefix": "I{{word}}"
  },

  "file_generation_rules": {
    "model": [
      {
        "template": "enterprise_model",
        "output_path": "src/models/{{snake_case}}.cr",
        "transformations": {
          "model_name": "pascal_case",
          "file_name": "snake_case"
        }
      },
      {
        "template": "model_spec",
        "output_path": "spec/models/{{snake_case}}_spec.cr",
        "transformations": {
          "model_name": "pascal_case",
          "file_name": "snake_case"
        }
      },
      {
        "template": "model_migration",
        "output_path": "db/migrations/{{timestamp}}_create_{{snake_case_plural}}.sql",
        "transformations": {
          "table_name": "snake_case_plural",
          "model_name": "pascal_case"
        },
        "conditions": {
          "auto_create_migration": "true"
        }
      }
    ],

    "controller": [
      {
        "template": "api_controller",
        "output_path": "src/controllers/{{snake_case_plural}}_controller.cr",
        "transformations": {
          "controller_name": "pascal_case_plural",
          "resource_name": "snake_case",
          "resource_plural": "snake_case_plural"
        }
      },
      {
        "template": "controller_spec",
        "output_path": "spec/controllers/{{snake_case_plural}}_controller_spec.cr",
        "transformations": {
          "controller_name": "pascal_case_plural",
          "resource_name": "snake_case"
        }
      }
    ],

    "service": [
      {
        "template": "domain_service",
        "output_path": "src/services/{{snake_case}}_service.cr",
        "transformations": {
          "service_name": "pascal_case",
          "resource_name": "pascal_case"
        }
      },
      {
        "template": "service_interface",
        "output_path": "src/interfaces/i_{{snake_case}}_service.cr",
        "transformations": {
          "interface_name": "pascal_case",
          "service_name": "pascal_case"
        }
      }
    ]
  },

  "post_generation_commands": [
    "crystal tool format src/**/*.cr",
    "echo 'Generated {{class_name}} with enterprise patterns'"
  ]
}
```

### YAML Configuration Example

```yaml
name: "Rails-Style MVC Generator"
description: "Generates MVC components following Rails conventions"

template_variables:
  namespace: "MyApp"
  use_strong_params: "true"
  default_scope: "web"

naming_conventions:
  model_suffix: ""
  controller_suffix: "Controller" 
  helper_suffix: "Helper"
  table_naming: "pluralized_snake_case"

file_generation_rules:
  scaffold:
    - template: "scaffold_model"
      output_path: "src/models/{{snake_case}}.cr"
      transformations:
        model_name: "pascal_case"
        table_name: "snake_case_plural"
    
    - template: "scaffold_controller"
      output_path: "src/controllers/{{snake_case_plural}}_controller.cr"
      transformations:
        controller_name: "pascal_case_plural"
        model_name: "pascal_case"
        resource_name: "snake_case"
        resource_plural: "snake_case_plural"
    
    - template: "scaffold_views_index"
      output_path: "src/views/{{snake_case_plural}}/index.ecr"
      transformations:
        resource_name: "snake_case"
        resource_plural: "snake_case_plural"
        title: "title_case_plural"
    
    - template: "scaffold_views_show" 
      output_path: "src/views/{{snake_case_plural}}/show.ecr"
      transformations:
        resource_name: "snake_case"
        title: "title_case"
    
    - template: "scaffold_views_form"
      output_path: "src/views/{{snake_case_plural}}/_form.ecr"
      transformations:
        resource_name: "snake_case"
        model_name: "pascal_case"

    - template: "scaffold_migration"
      output_path: "db/migrations/{{timestamp}}_create_{{snake_case_plural}}.sql"
      transformations:
        table_name: "snake_case_plural"
        model_name: "pascal_case"
```

## Template File Examples

### Model Template (`.amber/templates/enterprise_model.amber-template`)

```crystal
require "./base_model"

module {{namespace}}
  class {{class_name}} < BaseModel
    {{#if use_audit_fields}}
    include AuditFields
    {{/if}}
    
    {{#if database_timestamps}}
    property created_at : Time?
    property updated_at : Time?
    {{/if}}

    # Add your properties here
    # Example: property name : String
    
    def self.table_name
      "{{snake_case_plural}}"
    end

    {{#if use_audit_fields}}
    def self.auditable_fields
      %w[created_at updated_at created_by_user_id]
    end
    {{/if}}
  end
end
```

### Controller Template (`.amber/templates/api_controller.amber-template`)

```crystal
module {{namespace}}
  class {{controller_name}} < ApplicationController
    before_action :set_{{resource_name}}, only: [:show, :update, :destroy]

    # GET /{{resource_plural}}
    def index
      {{resource_plural}} = {{class_name}}.all
      render json: {{resource_plural}}
    end

    # GET /{{resource_plural}}/1
    def show
      render json: @{{resource_name}}
    end

    # POST /{{resource_plural}}
    def create
      @{{resource_name}} = {{class_name}}.new({{resource_name}}_params)

      if @{{resource_name}}.save
        render json: @{{resource_name}}, status: :created
      else
        render json: @{{resource_name}}.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /{{resource_plural}}/1
    def update
      if @{{resource_name}}.update({{resource_name}}_params)
        render json: @{{resource_name}}
      else
        render json: @{{resource_name}}.errors, status: :unprocessable_entity
      end
    end

    # DELETE /{{resource_plural}}/1
    def destroy
      @{{resource_name}}.destroy
      head :no_content
    end

    private

    def set_{{resource_name}}
      @{{resource_name}} = {{class_name}}.find(params[:id])
    end

    def {{resource_name}}_params
      params.require(:{{resource_name}}).permit(:name) # Add your permitted params
    end
  end
end
```

## Usage Examples

```bash
# Uses the configured rules and templates
$ amber generate model User
# Creates:
# - src/models/user.cr (from enterprise_model.amber-template)
# - spec/models/user_spec.cr (from model_spec.amber-template)  
# - db/migrations/1234567890_create_users.sql (from model_migration.amber-template)

$ amber generate controller Post
# Creates:
# - src/controllers/posts_controller.cr (from api_controller.amber-template)
# - spec/controllers/posts_controller_spec.cr (from controller_spec.amber-template)

$ amber generate scaffold Product name:string price:decimal
# Creates complete CRUD setup with all configured templates
```

## Benefits of This Approach

### **1. True Separation of Concerns**
- Configuration defines **what** and **where**
- Templates define **how** and **content**
- Transformations handle **naming conventions**

### **2. Rails-like Flexibility**
- Support for singular/plural conventions
- Multiple capitalization styles
- Configurable file/folder structures
- Conditional generation based on project settings

### **3. Reusable Templates**
- Same template can be used with different naming rules
- Templates are project-agnostic
- Easy to share templates across teams

### **4. Convention over Configuration**
- Sensible defaults for standard cases
- Full customization when needed
- Gradual adoption - works without config files

This approach gives you the power of Rails generators with the flexibility to adapt to any team's conventions while maintaining the simplicity of the Crystal standard library.

## 7. Directory Structure

```
src/amber_cli/
├── amber_cli.cr                 # Main entry point
├── core/                        # Core framework classes
│   ├── base_command.cr         # Abstract command base
│   ├── command_registry.cr     # Command registration system
│   ├── template_engine.cr      # Template processing (replaces teeplate)
│   ├── file_operations.cr      # File system utilities
│   └── process_manager.cr      # Process execution utilities
├── commands/                    # CLI command implementations
│   ├── new_command.cr          # amber new
│   ├── generate_command.cr     # amber generate
│   ├── database_command.cr     # amber database
│   ├── watch_command.cr        # amber watch
│   ├── routes_command.cr       # amber routes
│   ├── encrypt_command.cr      # amber encrypt
│   └── exec_command.cr         # amber exec
├── generators/                  # Code generation classes
│   ├── base_generator.cr       # Abstract generator base
│   ├── app_generator.cr        # Full application generation
│   ├── model_generator.cr      # Model generation
│   ├── controller_generator.cr # Controller generation
│   ├── migration_generator.cr  # Migration generation
│   └── scaffold_generator.cr   # Full CRUD scaffolding
├── helpers/                     # Utility modules
│   ├── string_inflector.cr     # String manipulation (pluralize, etc.)
│   ├── database_helper.cr      # Database operations
│   └── file_watcher.cr         # File system monitoring
└── templates/                   # Template files (simplified ECR)
    ├── app/                    # Application templates
    ├── model/                  # Model templates
    ├── controller/             # Controller templates
    ├── migration/              # Migration templates
    └── scaffold/               # Scaffold templates
```

## 8. Main Entry Point

```crystal
# src/amber_cli.cr
require "./amber_cli/core/*"
require "./amber_cli/commands/*"
require "./amber_cli/generators/*"
require "./amber_cli/helpers/*"

module AmberCLI
  VERSION = "2.0.0"

  def self.run(args = ARGV)
    if args.empty?
      show_help
      return
    end

    command_name = args[0]
    command_args = args[1..]

    Core::CommandRegistry.execute_command(command_name, command_args)
  end

  private def self.show_help
    puts <<-HELP
    Amber CLI v#{VERSION} - Crystal web framework tool

    Usage: amber <command> [options]

    Available commands:
      new (n)        Create a new Amber application
      generate (g)   Generate application components  
      database (db)  Database operations and migrations
      watch (w)      Start development server with file watching
      routes         Display application routes
      encrypt (e)    Encrypt/decrypt environment files
      exec (x)       Execute Crystal code in application context

    Use 'amber <command> --help' for more information about a command.
    HELP
  end
end

# Run the CLI if this is the main file
AmberCLI.run if PROGRAM_NAME.includes?("amber")
```

## Benefits of This Architecture

### 1. **Zero External Dependencies**
- Uses only Crystal's standard library
- No need for `cli`, `teeplate`, or other shards for core functionality
- Faster compilation and smaller binary size

### 2. **Clean, Maintainable Structure**  
- Clear separation of concerns
- Follows user's naming conventions
- Easy to test and extend

### 3. **Flexible Template System**
- Simple variable substitution
- Support for file and directory templates
- No external template engine dependencies

### 4. **Robust Command System**
- Built on Crystal's `OptionParser`
- Consistent error handling
- Easy command registration

### 5. **Process Manager Integration**
- Built-in process execution
- Proper error handling and status reporting
- Working directory management

## Migration Strategy

1. **Phase 1**: Implement core infrastructure (BaseCommand, CommandRegistry, TemplateEngine)
2. **Phase 2**: Migrate essential commands (new, generate, database)
3. **Phase 3**: Migrate generators and templates
4. **Phase 4**: Add development tools (watch, routes, etc.)
5. **Phase 5**: Comprehensive testing and optimization

This architecture maintains all current functionality while eliminating external dependencies and providing a clean, maintainable foundation for future development. 