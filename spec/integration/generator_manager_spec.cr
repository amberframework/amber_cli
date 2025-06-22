require "../amber_cli_spec"

describe AmberCLI::Core::ConfigurableGeneratorManager do
  describe "#generate" do
    context "with valid configuration and templates" do
      it "generates single file from configuration" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name"                  => "Simple Test Config",
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

          model_template = "class {{class_name}}\n  # Generated model\nend"
          SpecHelper.create_test_template(temp_dir, "basic_model", model_template)

          config_path = File.join(temp_dir, ".amber-generators.json")
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)
          config.should_not be_nil

          manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config.not_nil!)
          result = manager.generate("model", "user")

          result.should be_true

          # Verify file was created
          File.exists?("src/models/user.cr").should be_true

          content = File.read("src/models/user.cr")
          content.should eq("class User\n  # Generated model\nend")
        end
      end

      it "generates multiple files from single generator type" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name"                  => "Multi-file Config",
            "file_generation_rules" => {
              "scaffold" => [
                {
                  "template"        => "model_template",
                  "output_path"     => "src/models/{{snake_case}}.cr",
                  "transformations" => {
                    "class_name" => "pascal_case",
                  },
                },
                {
                  "template"        => "controller_template",
                  "output_path"     => "src/controllers/{{snake_case_plural}}_controller.cr",
                  "transformations" => {
                    "controller_name" => "pascal_case_plural",
                  },
                },
              ],
            },
          }

          SpecHelper.create_test_config(temp_dir, config_data)

          model_template = "class {{class_name}}\nend"
          controller_template = "class {{controller_name}}Controller\nend"

          SpecHelper.create_test_template(temp_dir, "model_template", model_template)
          SpecHelper.create_test_template(temp_dir, "controller_template", controller_template)

          config_path = File.join(temp_dir, ".amber-generators.json")
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)

          manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config.not_nil!)
          result = manager.generate("scaffold", "blog_post")

          result.should be_true

          # Verify both files were created
          File.exists?("src/models/blog_post.cr").should be_true
          File.exists?("src/controllers/blog_posts_controller.cr").should be_true

          model_content = File.read("src/models/blog_post.cr")
          model_content.should eq("class BlogPost\nend")

          controller_content = File.read("src/controllers/blog_posts_controller.cr")
          controller_content.should eq("class BlogPostsController\nend")
        end
      end

      it "applies template variables correctly" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name"               => "Template Variables Test",
            "template_variables" => {
              "namespace"  => "MyApp::Models",
              "base_class" => "ApplicationRecord",
              "author"     => "Test Developer",
            },
            "file_generation_rules" => {
              "model" => [
                {
                  "template"        => "advanced_model",
                  "output_path"     => "src/models/{{snake_case}}.cr",
                  "transformations" => {
                    "class_name" => "pascal_case",
                  },
                },
              ],
            },
          }

          SpecHelper.create_test_config(temp_dir, config_data)

          model_template = <<-CRYSTAL
          module {{namespace}}
            # {{class_name}} - Created by {{author}}
            class {{class_name}} < {{base_class}}
              # Model implementation
            end
          end
          CRYSTAL

          SpecHelper.create_test_template(temp_dir, "advanced_model", model_template)

          config_path = File.join(temp_dir, ".amber-generators.json")
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)

          manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config.not_nil!)
          result = manager.generate("model", "user")

          result.should be_true

          content = File.read("src/models/user.cr")
          content.should contain("module MyApp::Models")
          content.should contain("# User - Created by Test Developer")
          content.should contain("class User < ApplicationRecord")
        end
      end

      it "respects conditional generation rules" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name"               => "Conditional Test",
            "template_variables" => {
              "create_specs"     => "false",
              "create_migration" => "true",
            },
            "file_generation_rules" => {
              "model" => [
                {
                  "template"        => "model_file",
                  "output_path"     => "src/models/{{snake_case}}.cr",
                  "transformations" => {
                    "class_name" => "pascal_case",
                  },
                },
                {
                  "template"        => "spec_file",
                  "output_path"     => "spec/models/{{snake_case}}_spec.cr",
                  "transformations" => {
                    "class_name" => "pascal_case",
                  },
                  "conditions" => {
                    "create_specs" => "true",
                  },
                },
                {
                  "template"        => "migration_file",
                  "output_path"     => "db/migrations/create_{{snake_case_plural}}.sql",
                  "transformations" => {
                    "table_name" => "snake_case_plural",
                  },
                  "conditions" => {
                    "create_migration" => "true",
                  },
                },
              ],
            },
          }

          SpecHelper.create_test_config(temp_dir, config_data)

          SpecHelper.create_test_template(temp_dir, "model_file", "class {{class_name}}\nend")
          SpecHelper.create_test_template(temp_dir, "spec_file", "describe {{class_name}}\nend")
          SpecHelper.create_test_template(temp_dir, "migration_file", "CREATE TABLE {{table_name}};")

          config_path = File.join(temp_dir, ".amber-generators.json")
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)

          manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config.not_nil!)
          result = manager.generate("model", "product")

          result.should be_true

          # Model should be created (no conditions)
          File.exists?("src/models/product.cr").should be_true

          # Spec should NOT be created (create_specs = false)
          File.exists?("spec/models/product_spec.cr").should be_false

          # Migration should be created (create_migration = true)
          File.exists?("db/migrations/create_products.sql").should be_true

          migration_content = File.read("db/migrations/create_products.sql")
          migration_content.should eq("CREATE TABLE products;")
        end
      end
    end

    context "with custom transformations" do
      it "applies custom word transformations correctly" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name"               => "Custom Transform Test",
            "naming_conventions" => {
              "service_suffix" => "{{word}}Service",
              "api_prefix"     => "Api{{word}}",
            },
            "file_generation_rules" => {
              "service" => [
                {
                  "template"        => "service_template",
                  "output_path"     => "src/services/{{snake_case}}_service.cr",
                  "transformations" => {
                    "service_class" => "service_suffix",
                    "api_class"     => "api_prefix",
                  },
                },
              ],
            },
          }

          SpecHelper.create_test_config(temp_dir, config_data)

          service_template = "class {{service_class}}\n  # API: {{api_class}}\nend"
          SpecHelper.create_test_template(temp_dir, "service_template", service_template)

          config_path = File.join(temp_dir, ".amber-generators.json")
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)

          manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config.not_nil!)
          result = manager.generate("service", "payment_processor")

          result.should be_true

          content = File.read("src/services/payment_processor_service.cr")
          content.should contain("class PaymentProcessorService")
          content.should contain("# API: ApiPaymentProcessor")
        end
      end
    end

    context "error conditions" do
      it "returns false for unknown generator types" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name"                  => "Limited Config",
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
          result = manager.generate("unknown_type", "test")

          result.should be_false
        end
      end

      it "handles template loading errors" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name"                  => "Error Config",
            "file_generation_rules" => {
              "model" => [
                {
                  "template"        => "missing_template",
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
    end

    context "with complex real-world scenarios" do
      it "handles nested directory creation" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name"                  => "Nested Path Config",
            "file_generation_rules" => {
              "controller" => [
                {
                  "template"        => "api_controller",
                  "output_path"     => "src/controllers/api/v1/{{snake_case}}_controller.cr",
                  "transformations" => {
                    "controller_name" => "pascal_case",
                  },
                },
              ],
            },
          }

          SpecHelper.create_test_config(temp_dir, config_data)

          controller_template = "class Api::V1::{{controller_name}}Controller\nend"
          SpecHelper.create_test_template(temp_dir, "api_controller", controller_template)

          config_path = File.join(temp_dir, ".amber-generators.json")
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)

          manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config.not_nil!)
          result = manager.generate("controller", "users")

          result.should be_true

          # Verify nested directories were created
          File.exists?("src/controllers/api/v1/users_controller.cr").should be_true

          content = File.read("src/controllers/api/v1/users_controller.cr")
          content.should contain("class Api::V1::UsersController")
        end
      end

      it "processes multiple complex transformations" do
        SpecHelper.within_temp_directory do |temp_dir|
          config_data = {
            "name"                  => "Complex Transform Config",
            "file_generation_rules" => {
              "full_stack" => [
                {
                  "template"        => "complex_template",
                  "output_path"     => "src/{{snake_case}}/{{snake_case}}_handler.cr",
                  "transformations" => {
                    "class_name"    => "pascal_case",
                    "module_name"   => "pascal_case",
                    "constant_name" => "constant_case",
                    "method_name"   => "snake_case",
                    "table_name"    => "snake_case_plural",
                  },
                },
              ],
            },
          }

          SpecHelper.create_test_config(temp_dir, config_data)

          complex_template = <<-CRYSTAL
          module {{module_name}}
            # {{constant_name}} handler
            class {{class_name}}Handler
              TABLE = "{{table_name}}"
              
              def handle_{{method_name}}
                # Handler logic for {{class_name}}
              end
            end
          end
          CRYSTAL

          SpecHelper.create_test_template(temp_dir, "complex_template", complex_template)

          config_path = File.join(temp_dir, ".amber-generators.json")
          config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)

          manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config.not_nil!)
          result = manager.generate("full_stack", "blog_post")

          result.should be_true

          content = File.read("src/blog_post/blog_post_handler.cr")
          content.should contain("module BlogPost")
          content.should contain("# BLOG_POST handler")
          content.should contain("class BlogPostHandler")
          content.should contain("TABLE = \"blog_posts\"")
          content.should contain("def handle_blog_post")
          content.should contain("# Handler logic for BlogPost")
        end
      end
    end
  end

  describe "#available_generators" do
    it "returns list of configured generator types" do
      SpecHelper.within_temp_directory do |temp_dir|
        config_data = {
          "name"                  => "Multi Generator Config",
          "file_generation_rules" => {
            "model"      => [{"template" => "model", "output_path" => "src/models/{{snake_case}}.cr"}],
            "controller" => [{"template" => "controller", "output_path" => "src/controllers/{{snake_case}}.cr"}],
            "service"    => [{"template" => "service", "output_path" => "src/services/{{snake_case}}.cr"}],
          },
        }

        SpecHelper.create_test_config(temp_dir, config_data)

        config_path = File.join(temp_dir, ".amber-generators.json")
        config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)

        manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config.not_nil!)
        generators = manager.available_generators

        generators.should contain("model")
        generators.should contain("controller")
        generators.should contain("service")
        generators.size.should eq(3)
      end
    end

    it "returns empty array when no generators configured" do
      SpecHelper.within_temp_directory do |temp_dir|
        config_data = {"name" => "Empty Config"}
        SpecHelper.create_test_config(temp_dir, config_data)

        config_path = File.join(temp_dir, ".amber-generators.json")
        config = AmberCLI::Core::GeneratorConfig.load_from_file(config_path)

        manager = AmberCLI::Core::ConfigurableGeneratorManager.new(config.not_nil!)
        generators = manager.available_generators

        generators.should be_empty
      end
    end
  end
end
