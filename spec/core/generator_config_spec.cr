require "../amber_cli_spec"

describe AmberCLI::Core::GeneratorConfig do
  describe ".load_from_file" do
    context "with JSON configuration" do
      it "loads a basic JSON configuration" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name" => "Test Config",
            "description" => "A test configuration",
            "template_variables" => {
              "namespace" => "TestApp",
              "author" => "Test User"
            }
          }
          
          config_path = SpecHelper.create_test_config(temp_dir, config_data)
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)
          
          config.should_not be_nil
          config.not_nil!.name.should eq("Test Config")
          config.not_nil!.description.should eq("A test configuration")
          
          variables = config.not_nil!.template_variables_as_hash
          variables["namespace"].should eq("TestApp")
          variables["author"].should eq("Test User")
        end
      end

      it "loads complex JSON configuration with file generation rules" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name" => "Complex Config",
            "naming_conventions" => {
              "controller_suffix" => "{{word}}Controller",
              "service_pattern" => "{{word}}Service"
            },
            "file_generation_rules" => {
              "model" => [
                {
                  "template" => "enterprise_model",
                  "output_path" => "src/models/{{snake_case}}.cr",
                  "transformations" => {
                    "model_name" => "pascal_case",
                    "table_name" => "snake_case_plural"
                  }
                }
              ]
            },
            "post_generation_commands" => [
              "crystal tool format src/**/*.cr",
              "echo 'Generated {{class_name}}'"
            ]
          }
          
          config_path = SpecHelper.create_test_config(temp_dir, config_data)
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)
          
          config.should_not be_nil
          config = config.not_nil!
          
          config.naming_conventions_hash["controller_suffix"].should eq("{{word}}Controller")
          config.naming_conventions_hash["service_pattern"].should eq("{{word}}Service")
          
          rules = config.file_generation_rules
          rules.should_not be_nil
          rules.not_nil!.has_key?("model").should be_true
          
          model_rules = rules.not_nil!["model"]
          model_rules.size.should eq(1)
          model_rules[0].template.should eq("enterprise_model")
          model_rules[0].output_path.should eq("src/models/{{snake_case}}.cr")
          
          transformations = model_rules[0].transformations
          transformations.should_not be_nil
          transformations.not_nil!["model_name"].should eq("pascal_case")
          
          commands = config.post_generation_commands
          commands.should_not be_nil
          commands.not_nil!.size.should eq(2)
          commands.not_nil![0].should eq("crystal tool format src/**/*.cr")
        end
      end
    end

    context "with YAML configuration" do
      it "loads a basic YAML configuration" do
        SpecHelper.within_temp_directory do |temp_dir|
          yaml_content = <<-YAML
          name: "YAML Test Config"
          description: "A YAML test configuration"
          template_variables:
            namespace: "YamlApp"
            author: "YAML User"
          YAML
          
          config_path = File.join(temp_dir, ".amber-generators.yml")
          File.write(config_path, yaml_content)
          
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)
          
          config.should_not be_nil
          config.not_nil!.name.should eq("YAML Test Config")
          config.not_nil!.description.should eq("A YAML test configuration")
          
          variables = config.not_nil!.template_variables_as_hash
          variables["namespace"].should eq("YamlApp")
          variables["author"].should eq("YAML User")
        end
      end

      it "loads complex YAML configuration with nested structures" do
        SpecHelper.within_temp_directory do |temp_dir|
          yaml_content = <<-YAML
          name: "Complex YAML Config"
          naming_conventions:
            controller_suffix: "{{word}}Controller"
            model_prefix: "App{{word}}"
          file_generation_rules:
            scaffold:
              - template: "scaffold_model"
                output_path: "src/models/{{snake_case}}.cr"
                transformations:
                  model_name: "pascal_case"
                  table_name: "snake_case_plural"
                conditions:
                  create_model: "true"
              - template: "scaffold_controller"
                output_path: "src/controllers/{{snake_case_plural}}_controller.cr"
                transformations:
                  controller_name: "pascal_case_plural"
          dependencies:
            - "uuid"
            - "crypto"
          YAML
          
          config_path = File.join(temp_dir, ".amber-generators.yaml")
          File.write(config_path, yaml_content)
          
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)
          
          config.should_not be_nil
          config = config.not_nil!
          
          conventions = config.naming_conventions_hash
          conventions["controller_suffix"].should eq("{{word}}Controller")
          conventions["model_prefix"].should eq("App{{word}}")
          
          rules = config.file_generation_rules.not_nil!["scaffold"]
          rules.size.should eq(2)
          
          # Test first rule (model)
          model_rule = rules[0]
          model_rule.template.should eq("scaffold_model")
          model_rule.output_path.should eq("src/models/{{snake_case}}.cr")
          
          model_conditions = model_rule.conditions
          model_conditions.should_not be_nil
          model_conditions.not_nil!["create_model"].should eq("true")
          
          # Test second rule (controller)
          controller_rule = rules[1]
          controller_rule.template.should eq("scaffold_controller")
          controller_rule.output_path.should eq("src/controllers/{{snake_case_plural}}_controller.cr")
          
          # Test dependencies
          deps = config.dependencies
          deps.should_not be_nil
          deps.not_nil!.should contain("uuid")
          deps.not_nil!.should contain("crypto")
        end
      end
    end

    context "error handling" do
      it "returns nil for non-existent files" do
        config = AmberCLI::Core::GeneratorConfig.load_from_file("non_existent_file.json")
        config.should be_nil
      end

      it "returns nil for unsupported file extensions" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_path = File.join(temp_dir, "config.txt")
          File.write(config_path, "some content")
          
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)
          config.should be_nil
        end
      end

      it "handles invalid JSON gracefully" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_path = File.join(temp_dir, "invalid.json")
          File.write(config_path, "{invalid json content")
          
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)
          config.should be_nil
        end
      end

      it "handles invalid YAML gracefully" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_path = File.join(temp_dir, "invalid.yml")
          File.write(config_path, "invalid: yaml: content: :")
          
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)
          config.should be_nil
        end
      end
    end

    context "minimal configuration" do
      it "loads configuration with only required fields" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {"name" => "Minimal Config"}
          config_path = SpecHelper.create_test_config(temp_dir, config_data)
          
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)
          
          config.should_not be_nil
          config.not_nil!.name.should eq("Minimal Config")
          config.not_nil!.description.should be_nil
          config.not_nil!.template_variables_as_hash.should be_empty
          config.not_nil!.naming_conventions_hash.should be_empty
        end
      end
    end
  end

  describe "#template_variables_as_hash" do
    context "with mixed data types" do
      it "converts JSON::Any values to strings" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name" => "Type Test",
            "template_variables" => {
              "string_value" => "test",
              "number_value" => 42,
              "boolean_value" => true,
              "null_value" => nil
            }
          }
          
          config_path = SpecHelper.create_test_config(temp_dir, config_data)
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)
          
          variables = config.not_nil!.template_variables_as_hash
          variables["string_value"].should eq("test")
          variables["number_value"].should eq("42")
          variables["boolean_value"].should eq("true")
          variables.has_key?("null_value").should be_false # nil values might be skipped
        end
      end
    end
  end

  describe "#naming_conventions_hash" do
    it "returns empty hash when naming_conventions is nil" do
      SpecHelper.within_temp_directory do |temp_dir|
        config_data = {"name" => "No Conventions"}
        config_path = SpecHelper.create_test_config(temp_dir, config_data)
        
        config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)
        config.not_nil!.naming_conventions_hash.should be_empty
      end
    end

    it "returns the naming conventions when present" do
      SpecHelper.within_temp_directory do |temp_dir|
        config_data = {
          "name" => "With Conventions",
          "naming_conventions" => {
            "suffix" => "{{word}}Suffix",
            "prefix" => "Pre{{word}}"
          }
        }
        config_path = SpecHelper.create_test_config(temp_dir, config_data)
        
        config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)
        conventions = config.not_nil!.naming_conventions_hash
        
        conventions["suffix"].should eq("{{word}}Suffix")
        conventions["prefix"].should eq("Pre{{word}}")
      end
    end
  end
end

describe AmberCLI::Core::FileGenerationRule do
  describe "#template_file_path" do
    it "constructs correct template file path" do
      rule = AmberCLI::Core::FileGenerationRule.new(
        template: "test_template",
        output_path: "src/test.cr",
        transformations: nil,
        conditions: nil
      )
      
      template_path = rule.template_file_path("/templates")
      template_path.should eq("/templates/test_template.amber-template")
    end

    it "handles template directory with trailing slash" do
      rule = AmberCLI::Core::FileGenerationRule.new(
        template: "test_template",
        output_path: "src/test.cr",
        transformations: nil,
        conditions: nil
      )
      
      template_path = rule.template_file_path("/templates/")
      template_path.should eq("/templates/test_template.amber-template")
    end
  end
end 