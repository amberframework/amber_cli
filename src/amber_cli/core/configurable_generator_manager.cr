require "./generator_config"
require "./template_engine"

module AmberCLI::Core
  class ConfigurableGeneratorManager
    @config : GeneratorConfig
    @template_engine : TemplateEngine

    def initialize(@config : GeneratorConfig)
      @template_engine = TemplateEngine.new
    end

    def generate(generator_type : String, name : String) : Bool
      rules = @config.file_generation_rules
      return false unless rules && rules.has_key?(generator_type)
      
      generator_rules = rules[generator_type]
      template_variables = @config.template_variables_as_hash
      template_dir = File.join(Dir.current, ".amber", "templates")
      
      begin
        generator_rules.each do |rule|
          generated_files = @template_engine.generate_file_from_rule(rule, name, template_dir, template_variables)
          
          generated_files.each do |file_info|
            # Create directory if needed
            dir = File.dirname(file_info[:path])
            Dir.mkdir_p(dir) unless Dir.exists?(dir)
            
            # Write file
            File.write(file_info[:path], file_info[:content])
          end
        end
        
        # Execute post-generation commands if any
        if commands = @config.post_generation_commands
          execute_post_generation_commands(commands, name, template_variables)
        end
        
        true
      rescue
        false
      end
    end

    def available_generators : Array(String)
      if rules = @config.file_generation_rules
        rules.keys
      else
        [] of String
      end
    end

    private def execute_post_generation_commands(commands : Array(String), name : String, variables : Hash(String, String))
      # Stub implementation for post-generation commands
      # In real implementation, this would execute shell commands
    end
  end
end 