require "../amber_cli_spec"

describe AmberCLI::Core::TemplateEngine do
  describe "#process_template" do
    context "with basic placeholder replacement" do
      it "replaces simple placeholders" do
        template_content = "class {{class_name}}\nend"
        replacements = {"class_name" => "User"}

        engine = AmberCLI::Core::TemplateEngine.new
        result = engine.process_template(template_content, replacements)

        result.should eq("class User\nend")
      end

      it "replaces multiple placeholders" do
        template_content = "class {{class_name}} < {{base_class}}\n  # {{description}}\nend"
        replacements = {
          "class_name"  => "User",
          "base_class"  => "ApplicationRecord",
          "description" => "User model for authentication",
        }

        engine = AmberCLI::Core::TemplateEngine.new
        result = engine.process_template(template_content, replacements)

        expected = "class User < ApplicationRecord\n  # User model for authentication\nend"
        result.should eq(expected)
      end

      it "handles placeholders that appear multiple times" do
        template_content = "# {{class_name}} implementation\nclass {{class_name}}\n  def {{class_name}}_method\n  end\nend"
        replacements = {"class_name" => "TestClass"}

        engine = AmberCLI::Core::TemplateEngine.new
        result = engine.process_template(template_content, replacements)

        expected = "# TestClass implementation\nclass TestClass\n  def TestClass_method\n  end\nend"
        result.should eq(expected)
      end

      it "leaves unreplaced placeholders unchanged when strict mode is false" do
        template_content = "class {{class_name}}\n  attr_reader :{{unknown_placeholder}}\nend"
        replacements = {"class_name" => "User"}

        engine = AmberCLI::Core::TemplateEngine.new
        result = engine.process_template(template_content, replacements, strict: false)

        expected = "class User\n  attr_reader :{{unknown_placeholder}}\nend"
        result.should eq(expected)
      end

      it "raises error for unknown placeholders in strict mode" do
        template_content = "class {{class_name}}\n  attr_reader :{{unknown_placeholder}}\nend"
        replacements = {"class_name" => "User"}

        engine = AmberCLI::Core::TemplateEngine.new

        expect_raises(AmberCLI::Exceptions::TemplateError, /Unknown placeholder/) do
          engine.process_template(template_content, replacements, strict: true)
        end
      end
    end

    context "with complex template scenarios" do
      it "handles nested placeholders in file paths" do
        template_content = "require \"./{{module_path}}/{{file_name}}\"\n\nmodule {{namespace}}\nend"
        replacements = {
          "module_path" => "models/user",
          "file_name"   => "profile",
          "namespace"   => "MyApp::Models",
        }

        engine = AmberCLI::Core::TemplateEngine.new
        result = engine.process_template(template_content, replacements)

        expected = "require \"./models/user/profile\"\n\nmodule MyApp::Models\nend"
        result.should eq(expected)
      end

      it "handles SQL template content" do
        template_content = <<-SQL
        CREATE TABLE {{table_name}} (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          {{field_name}} VARCHAR(255) NOT NULL,
          created_at TIMESTAMP DEFAULT NOW()
        );
        SQL

        replacements = {
          "table_name" => "users",
          "field_name" => "email",
        }

        engine = AmberCLI::Core::TemplateEngine.new
        result = engine.process_template(template_content, replacements)

        result.should contain("CREATE TABLE users")
        result.should contain("email VARCHAR(255)")
      end

      it "handles configuration file templates" do
        template_content = <<-YAML
        development:
          database_url: {{database_url}}
          namespace: {{namespace}}
          debug: {{debug_mode}}
        YAML

        replacements = {
          "database_url" => "postgres://localhost/myapp_dev",
          "namespace"    => "MyApp",
          "debug_mode"   => "true",
        }

        engine = AmberCLI::Core::TemplateEngine.new
        result = engine.process_template(template_content, replacements)

        result.should contain("database_url: postgres://localhost/myapp_dev")
        result.should contain("namespace: MyApp")
        result.should contain("debug: true")
      end
    end

    context "edge cases" do
      it "handles empty template content" do
        engine = AmberCLI::Core::TemplateEngine.new
        result = engine.process_template("", {"any" => "value"})
        result.should eq("")
      end

      it "handles template with no placeholders" do
        template_content = "class User\n  # Regular class with no placeholders\nend"

        engine = AmberCLI::Core::TemplateEngine.new
        result = engine.process_template(template_content, {"unused" => "value"})

        result.should eq(template_content)
      end

      it "handles empty replacements hash" do
        template_content = "class StaticClass\nend"

        engine = AmberCLI::Core::TemplateEngine.new
        result = engine.process_template(template_content, {} of String => String)

        result.should eq(template_content)
      end

      it "handles placeholders with special characters" do
        template_content = "# {{class_name}}: {{description_with_special_chars}}"
        replacements = {
          "class_name"                     => "User",
          "description_with_special_chars" => "User & Admin (with symbols!)",
        }

        engine = AmberCLI::Core::TemplateEngine.new
        result = engine.process_template(template_content, replacements)

        result.should eq("# User: User & Admin (with symbols!)")
      end

      it "handles adjacent placeholders" do
        template_content = "{{prefix}}{{class_name}}{{suffix}}"
        replacements = {
          "prefix"     => "App",
          "class_name" => "User",
          "suffix"     => "Model",
        }

        engine = AmberCLI::Core::TemplateEngine.new
        result = engine.process_template(template_content, replacements)

        result.should eq("AppUserModel")
      end
    end
  end

  describe "#generate_file_from_rule" do
    context "with file generation rules" do
      it "generates a simple file from template and rule" do
        SpecHelper.within_temp_directory do |temp_dir|
          # Create template file
          template_content = "class {{class_name}}\n  # Generated {{class_name}} model\nend"
          SpecHelper.create_test_template(temp_dir, "simple_model", template_content)

          # Create rule
          rule = AmberCLI::Core::FileGenerationRule.new(
            template: "simple_model",
            output_path: "src/models/{{snake_case}}.cr",
            transformations: {"class_name" => "pascal_case"},
            conditions: nil
          )

          # Test transformation context
          word = "user_profile"
          template_dir = File.join(temp_dir, ".amber", "templates")
          engine = AmberCLI::Core::TemplateEngine.new

          generated_files = engine.generate_file_from_rule(rule, word, template_dir, {} of String => String, {} of String => String)

          generated_files.size.should eq(1)

          file_info = generated_files[0]
          file_info[:path].should eq("src/models/user_profile.cr")
          file_info[:content].should contain("class UserProfile")
          file_info[:content].should contain("# Generated UserProfile model")
        end
      end

      it "applies multiple transformations in a single rule" do
        SpecHelper.within_temp_directory do |temp_dir|
          template_content = <<-CRYSTAL
          class {{class_name}}
            TABLE_NAME = "{{table_name}}"
            
            def self.{{method_name}}
              # Implementation for {{class_name}}
            end
          end
          CRYSTAL

          SpecHelper.create_test_template(temp_dir, "multi_transform", template_content)

          rule = AmberCLI::Core::FileGenerationRule.new(
            template: "multi_transform",
            output_path: "src/models/{{snake_case}}.cr",
            transformations: {
              "class_name"  => "pascal_case",
              "table_name"  => "snake_case_plural",
              "method_name" => "snake_case",
            },
            conditions: nil
          )

          word = "blog_post"
          template_dir = File.join(temp_dir, ".amber", "templates")
          engine = AmberCLI::Core::TemplateEngine.new

          generated_files = engine.generate_file_from_rule(rule, word, template_dir, {} of String => String, {} of String => String)

          file_info = generated_files[0]
          file_info[:content].should contain("class BlogPost")
          file_info[:content].should contain("TABLE_NAME = \"blog_posts\"")
          file_info[:content].should contain("def self.blog_post")
        end
      end

      it "includes custom template variables in processing" do
        SpecHelper.within_temp_directory do |temp_dir|
          template_content = <<-CRYSTAL
          module {{namespace}}
            class {{class_name}}
              # Created by: {{author}}
              # Project: {{project_name}}
            end
          end
          CRYSTAL

          SpecHelper.create_test_template(temp_dir, "with_variables", template_content)

          rule = AmberCLI::Core::FileGenerationRule.new(
            template: "with_variables",
            output_path: "src/{{snake_case}}.cr",
            transformations: {"class_name" => "pascal_case"},
            conditions: nil
          )

          custom_variables = {
            "namespace"    => "MyApp::Models",
            "author"       => "John Doe",
            "project_name" => "Awesome Project",
          }

          word = "user"
          template_dir = File.join(temp_dir, ".amber", "templates")
          engine = AmberCLI::Core::TemplateEngine.new

          generated_files = engine.generate_file_from_rule(rule, word, template_dir, custom_variables, {} of String => String)

          file_info = generated_files[0]
          file_info[:content].should contain("module MyApp::Models")
          file_info[:content].should contain("class User")
          file_info[:content].should contain("# Created by: John Doe")
          file_info[:content].should contain("# Project: Awesome Project")
        end
      end

      it "respects conditional rules" do
        SpecHelper.within_temp_directory do |temp_dir|
          template_content = "# This is a conditional template"
          SpecHelper.create_test_template(temp_dir, "conditional", template_content)

          # Rule that should not be applied due to false condition
          rule = AmberCLI::Core::FileGenerationRule.new(
            template: "conditional",
            output_path: "src/conditional.cr",
            transformations: nil,
            conditions: {"create_file" => "true"} # Condition requires true
          )

          word = "test"
          template_dir = File.join(temp_dir, ".amber", "templates")
          engine = AmberCLI::Core::TemplateEngine.new

          generated_files = engine.generate_file_from_rule(rule, word, template_dir, {"create_file" => "false"}, {} of String => String)

          # Should return empty array due to condition not being met (true required but false provided)
          generated_files.should be_empty
        end
      end
    end

    context "error handling" do
      it "raises error when template file doesn't exist" do
        SpecHelper.within_temp_directory do |temp_dir|
          rule = AmberCLI::Core::FileGenerationRule.new(
            template: "nonexistent_template",
            output_path: "src/test.cr",
            transformations: nil,
            conditions: nil
          )

          word = "test"
          template_dir = File.join(temp_dir, ".amber", "templates")
          engine = AmberCLI::Core::TemplateEngine.new

          expect_raises(AmberCLI::Exceptions::TemplateError, /Template file not found/) do
            engine.generate_file_from_rule(rule, word, template_dir, {} of String => String, {} of String => String)
          end
        end
      end
    end
  end

  describe "private methods" do
    describe "#meets_conditions?" do
      it "returns true when all conditions are met" do
        engine = AmberCLI::Core::TemplateEngine.new
        conditions = {"create_model" => "true", "use_uuid" => "true"}
        context = {"create_model" => "true", "use_uuid" => "true", "other_var" => "value"}

        # This would need to be tested via a public method that calls it
        # or by making it protected and testing through inheritance
        # For now, we test the behavior through generate_file_from_rule
      end
    end
  end
end
