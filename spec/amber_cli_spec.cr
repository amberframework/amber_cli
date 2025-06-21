require "spec"
require "file_utils"
require "json"
require "yaml"

# Only require our new core modules directly, avoiding the main amber_cli.cr which has dependencies
require "../src/amber_cli/exceptions"
require "../src/amber_cli/core/word_transformer"
require "../src/amber_cli/core/generator_config"
require "../src/amber_cli/core/template_engine"
require "../src/amber_cli/core/base_command"
require "../src/amber_cli/core/configurable_generator_manager"

# Test helpers
module SpecHelper
  def self.create_temp_directory
    temp_dir = File.tempname("amber_cli_spec")
    Dir.mkdir_p(temp_dir)
    temp_dir
  end

  def self.cleanup_temp_directory(dir : String)
    FileUtils.rm_rf(dir) if Dir.exists?(dir)
  end

  def self.create_test_config(dir : String, config : Hash) : String
    config_path = File.join(dir, ".amber-generators.json")
    File.write(config_path, config.to_json)
    config_path
  end

  def self.create_test_template(dir : String, template_name : String, content : String) : String
    template_dir = File.join(dir, ".amber", "templates")
    Dir.mkdir_p(template_dir)
    template_path = File.join(template_dir, "#{template_name}.amber-template")
    File.write(template_path, content)
    template_path
  end

  def self.within_temp_directory(&block)
    temp_dir = create_temp_directory
    original_dir = Dir.current
    
    begin
      Dir.cd(temp_dir)
      yield temp_dir
    ensure
      Dir.cd(original_dir)
      cleanup_temp_directory(temp_dir)
    end
  end
end

# Include all spec files
require "./core/word_transformer_spec"
require "./core/generator_config_spec"
require "./core/template_engine_spec"
require "./commands/base_command_spec"
require "./integration/generator_manager_spec"

describe "Amber CLI New Architecture" do
  it "loads all core modules successfully" do
    # Test that all our new classes can be instantiated
    transformer = AmberCLI::Core::WordTransformer
    engine = AmberCLI::Core::TemplateEngine.new
    
    transformer.should_not be_nil
    engine.should_not be_nil
    
    # Basic functionality test
    result = transformer.transform("user", "pascal_case")
    result.should eq("User")
  end
end
