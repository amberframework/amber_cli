require "../amber_cli_spec"

describe "End-to-End Integration Tests" do
  describe "Complete Generator Workflow" do
    context "with Rails-like conventions" do
      it "generates a complete model with standard Rails conventions" do
        SpecHelper.within_temp_directory do |temp_dir|
          # Setup Rails-like configuration
          config_data = {
            "name"               => "Rails Convention Config",
            "description"        => "Standard Rails-like naming conventions",
            "naming_conventions" => {
              "controller_suffix" => "{{word}}Controller",
              "model_class"       => "{{word}}",
              "table_name"        => "{{word}}_table",
            },
            "template_variables" => {
              "namespace"  => "MyApp",
              "author"     => "Test Developer",
              "base_class" => "ApplicationRecord",
            },
            "file_generation_rules" => {
              "model" => [
                {
                  "template"        => "rails_model",
                  "output_path"     => "src/models/{{snake_case}}.cr",
                  "transformations" => {
                    "class_name" => "pascal_case",
                    "table_name" => "snake_case_plural",
                  },
                },
                {
                  "template"        => "model_spec",
                  "output_path"     => "spec/models/{{snake_case}}_spec.cr",
                  "transformations" => {
                    "class_name" => "pascal_case",
                    "spec_name"  => "pascal_case",
                  },
                },
              ],
            },
            "post_generation_commands" => [
              "echo 'Generated {{class_name}} model'",
              "crystal tool format {{output_path}}",
            ],
          }

          SpecHelper.create_test_config(temp_dir, config_data)

          # Create model template
          model_template = <<-CRYSTAL
          require "./application_record"
          
          module {{namespace}}
            class {{class_name}} < {{base_class}}
              # {{class_name}} model
              # Created by: {{author}}
              
              table :{{table_name}}
              
              # Add your model logic here
            end
          end
          CRYSTAL

          SpecHelper.create_test_template(temp_dir, "rails_model", model_template)

          # Create spec template
          spec_template = <<-CRYSTAL
          require "../spec_helper"
          
          describe {{namespace}}::{{class_name}} do
            describe "{{spec_name}}" do
              it "should be valid" do
                {{snake_case}} = {{class_name}}.new
                {{snake_case}}.should_not be_nil
              end
            end
          end
          CRYSTAL

          SpecHelper.create_test_template(temp_dir, "model_spec", spec_template)

          # Load configuration and generate files
          config_path = File.join(temp_dir, ".amber-generators.json")
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)
          config.should_not be_nil

          # Test the generator manager
          manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config.not_nil!)
          result = manager.generate("model", "blog_post")

          result.should be_true

          # Verify model file was generated correctly
          model_path = "src/models/blog_post.cr"
          File.exists?(model_path).should be_true

          model_content = File.read(model_path)
          model_content.should contain("module MyApp")
          model_content.should contain("class BlogPost < ApplicationRecord")
          model_content.should contain("# Created by: Test Developer")
          model_content.should contain("table :blog_posts")

          # Verify spec file was generated correctly
          spec_path = "spec/models/blog_post_spec.cr"
          File.exists?(spec_path).should be_true

          spec_content = File.read(spec_path)
          spec_content.should contain("describe MyApp::BlogPost do")
          spec_content.should contain("describe \"BlogPost\" do")
          spec_content.should contain("blog_post = BlogPost.new")
        end
      end
    end

    context "with enterprise patterns" do
      it "generates enterprise-style architecture with namespaces" do
        SpecHelper.within_temp_directory do |temp_dir|
          # Setup enterprise configuration
          config_data = {
            "name"               => "Enterprise Config",
            "naming_conventions" => {
              "service_class"    => "{{word}}Service",
              "repository_class" => "{{word}}Repository",
              "interface_prefix" => "I{{word}}",
            },
            "template_variables" => {
              "company_namespace" => "Enterprise::Banking",
              "team"              => "Core Platform Team",
              "use_interfaces"    => "true",
            },
            "file_generation_rules" => {
              "service" => [
                {
                  "template"        => "enterprise_service",
                  "output_path"     => "src/services/{{snake_case}}_service.cr",
                  "transformations" => {
                    "service_name"   => "pascal_case",
                    "interface_name" => "pascal_case",
                  },
                  "conditions" => {
                    "use_interfaces" => "true",
                  },
                },
                {
                  "template"        => "service_interface",
                  "output_path"     => "src/interfaces/i_{{snake_case}}_service.cr",
                  "transformations" => {
                    "interface_name" => "pascal_case",
                  },
                  "conditions" => {
                    "use_interfaces" => "true",
                  },
                },
                {
                  "template"        => "service_repository",
                  "output_path"     => "src/repositories/{{snake_case}}_repository.cr",
                  "transformations" => {
                    "repository_name" => "pascal_case",
                    "service_name"    => "pascal_case",
                  },
                },
              ],
            },
          }

          SpecHelper.create_test_config(temp_dir, config_data)

          # Create enterprise service template
          service_template = <<-CRYSTAL
          require "../interfaces/i_{{snake_case}}_service"
          require "../repositories/{{snake_case}}_repository"
          
          module {{company_namespace}}::Services
            # {{service_name}}Service
            # Maintained by: {{team}}
            class {{service_name}}Service
              include I{{interface_name}}Service
              
              def initialize(@repository : {{repository_name}}Repository)
              end
              
              def perform_{{snake_case}}_operation
                # Business logic implementation
                @repository.save_{{snake_case}}_data
              end
            end
          end
          CRYSTAL

          SpecHelper.create_test_template(temp_dir, "enterprise_service", service_template)

          # Create interface template
          interface_template = <<-CRYSTAL
          module {{company_namespace}}::Services
            # Interface for {{interface_name}}Service
            # Maintained by: {{team}}
            module I{{interface_name}}Service
              abstract def perform_{{snake_case}}_operation
            end
          end
          CRYSTAL

          SpecHelper.create_test_template(temp_dir, "service_interface", interface_template)

          # Create repository template
          repository_template = <<-CRYSTAL
          module {{company_namespace}}::Repositories
            # {{repository_name}}Repository
            # Maintained by: {{team}}
            class {{repository_name}}Repository
              def save_{{snake_case}}_data
                # Data persistence logic
              end
              
              def find_{{snake_case}}_by_id(id : String)
                # Query logic
              end
            end
          end
          CRYSTAL

          SpecHelper.create_test_template(temp_dir, "service_repository", repository_template)

          # Generate the service
          config_path = File.join(temp_dir, ".amber-generators.json")
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)
          config.should_not be_nil

          manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config.not_nil!)
          result = manager.generate("service", "payment_processor")

          result.should be_true

          # Verify service file
          service_path = "src/services/payment_processor_service.cr"
          File.exists?(service_path).should be_true

          service_content = File.read(service_path)
          service_content.should contain("module Enterprise::Banking::Services")
          service_content.should contain("class PaymentProcessorService")
          service_content.should contain("include IPaymentProcessorService")
          service_content.should contain("def perform_payment_processor_operation")
          service_content.should contain("# Maintained by: Core Platform Team")

          # Verify interface file
          interface_path = "src/interfaces/i_payment_processor_service.cr"
          File.exists?(interface_path).should be_true

          interface_content = File.read(interface_path)
          interface_content.should contain("module IPaymentProcessorService")
          interface_content.should contain("abstract def perform_payment_processor_operation")

          # Verify repository file
          repo_path = "src/repositories/payment_processor_repository.cr"
          File.exists?(repo_path).should be_true

          repo_content = File.read(repo_path)
          repo_content.should contain("class PaymentProcessorRepository")
          repo_content.should contain("def save_payment_processor_data")
          repo_content.should contain("def find_payment_processor_by_id")
        end
      end
    end

    context "with conditional generation" do
      it "only generates files when conditions are met" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name"               => "Conditional Config",
            "template_variables" => {
              "generate_specs" => "false",
              "use_database"   => "true",
            },
            "file_generation_rules" => {
              "controller" => [
                {
                  "template"        => "basic_controller",
                  "output_path"     => "src/controllers/{{snake_case}}_controller.cr",
                  "transformations" => {
                    "controller_name" => "pascal_case",
                  },
                },
                {
                  "template"        => "controller_spec",
                  "output_path"     => "spec/controllers/{{snake_case}}_controller_spec.cr",
                  "transformations" => {
                    "controller_name" => "pascal_case",
                  },
                  "conditions" => {
                    "generate_specs" => "true",
                  },
                },
                {
                  "template"        => "database_config",
                  "output_path"     => "config/{{snake_case}}_database.yml",
                  "transformations" => {
                    "table_name" => "snake_case_plural",
                  },
                  "conditions" => {
                    "use_database" => "true",
                  },
                },
              ],
            },
          }

          SpecHelper.create_test_config(temp_dir, config_data)

          # Create templates
          controller_template = "class {{controller_name}}Controller\nend"
          SpecHelper.create_test_template(temp_dir, "basic_controller", controller_template)

          spec_template = "describe {{controller_name}}Controller\nend"
          SpecHelper.create_test_template(temp_dir, "controller_spec", spec_template)

          db_template = "table_name: {{table_name}}\nuse_database: true"
          SpecHelper.create_test_template(temp_dir, "database_config", db_template)

          # Generate controller
          config_path = File.join(temp_dir, ".amber-generators.json")
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)

          manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config.not_nil!)
          result = manager.generate("controller", "users")

          result.should be_true

          # Controller should be generated (no conditions)
          File.exists?("src/controllers/users_controller.cr").should be_true

          # Spec should NOT be generated (generate_specs = false)
          File.exists?("spec/controllers/users_controller_spec.cr").should be_false

          # Database config should be generated (use_database = true)
          File.exists?("config/users_database.yml").should be_true

          db_content = File.read("config/users_database.yml")
          db_content.should contain("table_name: users")
        end
      end
    end

    context "with post-generation commands" do
      it "executes post-generation commands successfully" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name"                  => "Post Command Config",
            "file_generation_rules" => {
              "model" => [
                {
                  "template"        => "simple_model",
                  "output_path"     => "src/{{snake_case}}.cr",
                  "transformations" => {
                    "class_name" => "pascal_case",
                  },
                },
              ],
            },
            "post_generation_commands" => [
              "echo 'Generated: {{class_name}}' > generation.log",
              "echo 'File: {{output_path}}' >> generation.log",
            ],
          }

          SpecHelper.create_test_config(temp_dir, config_data)

          model_template = "class {{class_name}}\nend"
          SpecHelper.create_test_template(temp_dir, "simple_model", model_template)

          config_path = File.join(temp_dir, ".amber-generators.json")
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)

          manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config.not_nil!)
          result = manager.generate("model", "user")

          result.should be_true

          # Check that post-generation commands ran
          File.exists?("generation.log").should be_true

          log_content = File.read("generation.log")
          log_content.should contain("Generated: User")
          log_content.should contain("File: src/user.cr")
        end
      end
    end

    context "error scenarios" do
      it "handles missing template files gracefully" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name"                  => "Error Config",
            "file_generation_rules" => {
              "model" => [
                {
                  "template"        => "nonexistent_template",
                  "output_path"     => "src/{{snake_case}}.cr",
                  "transformations" => {
                    "class_name" => "pascal_case",
                  },
                },
              ],
            },
          }

          SpecHelper.create_test_config(temp_dir, config_data)

          config_path = File.join(temp_dir, ".amber-generators.json")
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)

          manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config.not_nil!)

          expect_raises(AmberCLI::Exceptions::TemplateError) do
            manager.generate("model", "user")
          end
        end
      end

      it "handles invalid generator types gracefully" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name"                  => "Valid Config",
            "file_generation_rules" => {
              "model" => [
                {
                  "template"        => "basic_template",
                  "output_path"     => "src/{{snake_case}}.cr",
                  "transformations" => {} of String => String,
                },
              ],
            },
          }

          SpecHelper.create_test_config(temp_dir, config_data)

          config_path = File.join(temp_dir, ".amber-generators.json")
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)

          manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config.not_nil!)
          result = manager.generate("nonexistent_generator", "test")

          result.should be_false
        end
      end
    end
  end

  describe "Command Integration" do
    context "with generate command" do
      it "integrates configuration loading with command execution" do
        SpecHelper.within_temp_directory do |temp_dir|
          # This would test the actual generate command integration
          # For now, we'll simulate the workflow

          config_data = {
            "name"                  => "Command Integration",
            "file_generation_rules" => {
              "model" => [
                {
                  "template"        => "basic_model",
                  "output_path"     => "src/models/{{snake_case}}.cr",
                  "transformations" => {
                    "class_name" => "pascal_case",
                  },
                },
              ],
            },
          }

          SpecHelper.create_test_config(temp_dir, config_data)

          model_template = "class {{class_name}}\n  # Basic model implementation\nend"
          SpecHelper.create_test_template(temp_dir, "basic_model", model_template)

          # This simulates what the actual GenerateCommand would do
          config_path = File.join(temp_dir, ".amber-generators.json")
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)

          if config
            manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config)
            result = manager.generate("model", "product")

            result.should be_true
            File.exists?("src/models/product.cr").should be_true

            content = File.read("src/models/product.cr")
            content.should contain("class Product")
          else
            fail "Configuration should have loaded successfully"
          end
        end
      end
    end
  end
end
