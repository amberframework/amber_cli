require "../core/base_command"
require "../static_assets"

# Builds and verifies the content-addressed static assets for an Amber web app.
#
# ## Usage
# ```
# amber assets build
# amber assets check
# ```
module AmberCLI::Commands
  class AssetsCommand < AmberCLI::Core::BaseCommand
    VALID_ACTIONS = %w[build check]

    getter action : String = ""

    def help_description : String
      "Builds or verifies the application's static assets"
    end

    def setup_command_options
      option_parser.separator ""
      option_parser.separator "Usage: amber assets <build|check>"
      option_parser.separator ""
      option_parser.separator "Actions:"
      option_parser.separator "  build  Fingerprint app/assets into public/assets and write the manifest"
      option_parser.separator "  check  Verify compiled files against the existing manifest without changing them"
    end

    def validate_arguments
      @action = remaining_arguments[0]? || ""
      return if VALID_ACTIONS.includes?(@action) && remaining_arguments.size == 1

      error "Choose exactly one asset action: #{VALID_ACTIONS.join(" or ")}"
      puts option_parser
      exit!(error: true)
    end

    def execute
      manifest = case action
                 when "build"
                   info "Compiling app/assets into public/assets..."
                   AmberCLI::StaticAssets.build
                 when "check"
                   info "Verifying public/assets against its manifest..."
                   AmberCLI::StaticAssets.check
                 else
                   raise "Unreachable asset action: #{action}"
                 end

      verb = action == "build" ? "Compiled" : "Verified"
      success "#{verb} #{manifest.assets.size} static assets."
    rescue ex : AssetPipeline::StaticAssets::Error
      error ex.message || "Static asset #{action} failed"
      exit!(error: true)
    end
  end
end

AmberCLI::Core::CommandRegistry.register("assets", Array(String).new, AmberCLI::Commands::AssetsCommand)
