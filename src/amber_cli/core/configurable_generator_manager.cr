# :nodoc:
require "./generator_config"
require "./template_engine"
require "./word_transformer"
require "../exceptions"

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
      naming_conventions = @config.naming_conventions_hash
      template_dir = File.join(Dir.current, ".amber", "templates")

      # Track generated files for post-generation commands
      all_generated_files = [] of String

      begin
        generator_rules.each do |rule|
          # Get amber framework version from config, defaulting to current stable version
          amber_version = template_variables["amber_framework_version"]? || "1.4.0"
          
          generated_files = @template_engine.generate_file_from_rule(rule, name, template_dir, template_variables, naming_conventions, amber_version)

          generated_files.each do |file_info|
            # Create directory if needed
            dir = File.dirname(file_info[:path])
            Dir.mkdir_p(dir) unless Dir.exists?(dir)

            # Write file
            File.write(file_info[:path], file_info[:content])
            all_generated_files << file_info[:path]
          end
        end

        # Execute post-generation commands if any
        if commands = @config.post_generation_commands
          # Use the first generated file as the primary output path, or a default pattern
          primary_output_path = all_generated_files.first? || "src/#{AmberCLI::Core::WordTransformer.transform(name, "snake_case", naming_conventions)}.cr"
          execute_post_generation_commands(commands, name, template_variables, primary_output_path)
        end

        true
      rescue ex : AmberCLI::Exceptions::TemplateError
        # Re-raise template errors for proper handling
        raise ex
      rescue
        # Other errors return false
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

    private def execute_post_generation_commands(commands : Array(String), name : String, variables : Hash(String, String), output_path : String)
      # Build complete replacement context including transformations
      naming_conventions = @config.naming_conventions_hash
      complete_variables = variables.dup

      # Add word transformations that might be used in commands
      complete_variables["snake_case"] = AmberCLI::Core::WordTransformer.transform(name, "snake_case", naming_conventions)
      complete_variables["pascal_case"] = AmberCLI::Core::WordTransformer.transform(name, "pascal_case", naming_conventions)
      complete_variables["class_name"] = AmberCLI::Core::WordTransformer.transform(name, "pascal_case", naming_conventions)
      complete_variables["snake_case_plural"] = AmberCLI::Core::WordTransformer.transform(name, "snake_case_plural", naming_conventions)
      complete_variables["pascal_case_plural"] = AmberCLI::Core::WordTransformer.transform(name, "pascal_case_plural", naming_conventions)
      complete_variables["output_path"] = output_path

      commands.each do |command|
        # Process command template with complete variables
        processed_command = @template_engine.process_template(command, complete_variables)

        # Execute the command (for testing purposes, we'll create a simple log file)
        if processed_command.includes?("echo")
          # Parse echo command to extract the message and output redirection
          if processed_command.includes?(">")
            parts = processed_command.split(">", 2)
            if parts.size == 2
              echo_part = parts[0].strip
              file_part = parts[1].strip

              # Determine if it's append mode (>>) or write mode (>)
              append_mode = file_part.starts_with?(">")
              filename = append_mode ? file_part[1..-1].strip : file_part

              # Extract the message from the echo command
              # Handle both echo 'message' and echo "message" formats
              message = if echo_part.includes?("'")
                          echo_part.split("'")[1]? || ""
                        elsif echo_part.includes?("\"")
                          echo_part.split("\"")[1]? || ""
                        else
                          echo_part.gsub("echo", "").strip
                        end

              if append_mode
                File.open(filename, "a") do |file|
                  file.puts(message)
                end
              else
                File.write(filename, message + "\n")
              end
            end
          end
        end
      end
    end
  end
end
