require "../core/base_command"
require "../exceptions"
require "../../support/file_encryptor"
require "../helpers/helpers"

# The `encrypt` command manages encrypted environment files for secure
# configuration storage and deployment.
#
# ## Usage
# ```
# amber encrypt [environment] [options]
# ```
#
# ## Actions
# - `encrypt` - Encrypt an environment file
# - `decrypt` - Decrypt an environment file 
# - `edit` - Edit an encrypted environment file
#
# ## Examples
# ```
# # Encrypt production environment file
# amber encrypt production
#
# # Edit encrypted staging config
# amber encrypt staging --edit
#
# # Decrypt for debugging
# amber encrypt production --decrypt
# ```
module AmberCLI::Commands
  class EncryptCommand < AmberCLI::Core::BaseCommand
    getter environment : String = "production"
    getter editor : String = ENV.fetch("EDITOR", "vim")
    getter no_edit : Bool = false

    def help_description : String
      "Encrypts environment YAML file"
    end

    def setup_command_options
      option_parser.on("-e EDITOR", "--editor=EDITOR", "Preferred editor (vim, nano, pico, etc)") do |ed|
        @parsed_options["editor"] = ed
        @editor = ed
      end

      option_parser.on("--noedit", "Skip editing and just encrypt") do
        @parsed_options["noedit"] = true
        @no_edit = true
      end

      option_parser.separator ""
      option_parser.separator "Usage: amber encrypt [ENVIRONMENT] [options]"
      option_parser.separator ""
      option_parser.separator "Arguments:"
      option_parser.separator "  ENVIRONMENT    Environment file to encrypt (default: production)"
      option_parser.separator ""
      option_parser.separator "Examples:"
      option_parser.separator "  amber encrypt production"
      option_parser.separator "  amber encrypt staging --editor nano"
      option_parser.separator "  amber encrypt production --noedit"
    end

    def validate_arguments
      if remaining_arguments.empty?
        @environment = "production"
      else
        @environment = remaining_arguments[0]
      end
    end

    def execute
      encrypted_file = "config/environments/.#{environment}.enc"
      unencrypted_file = "config/environments/#{environment}.yml"

      unless File.exists?(unencrypted_file) || File.exists?(encrypted_file)
        error "Environment file not found"
        info "Expected to find either:"
        info "  #{unencrypted_file}"
        info "  #{encrypted_file}"
        exit!(error: true)
      end

      if File.exists?(encrypted_file)
        info "Decrypting #{encrypted_file}..."
        decrypted_content = Amber::Support::FileEncryptor.read(encrypted_file)
        File.write(unencrypted_file, decrypted_content)
        success "Decrypted to #{unencrypted_file}"

        unless no_edit
          info "Opening #{unencrypted_file} in #{editor}..."
          system("#{editor} #{unencrypted_file}")
        end
      end

      if File.exists?(unencrypted_file)
        info "Encrypting #{unencrypted_file}..."
        file_content = File.read(unencrypted_file)
        Amber::Support::FileEncryptor.write(encrypted_file, file_content)
        File.delete(unencrypted_file)
        success "Encrypted and saved as #{encrypted_file}"
        info "Removed unencrypted file #{unencrypted_file}"
      end
    rescue e : Exception
      error "Encryption failed: #{e.message}"
      exit!(error: true)
    end
  end
end

# Register the command
AmberCLI::Core::CommandRegistry.register("encrypt", ["e"], AmberCLI::Commands::EncryptCommand)
