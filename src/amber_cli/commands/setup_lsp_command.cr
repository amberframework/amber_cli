require "../core/base_command"
require "../agent/install_claude_amber_lsp_plugin"

module AmberCLI::Commands
  # Registers the Amber LSP plugin in a project's Claude Code marketplace.
  class SetupLSPCommand < AmberCLI::Core::BaseCommand
    def help_description : String
      <<-HELP
      Set up the Amber LSP plugin for Claude Code

      Usage: amber setup:lsp

      This command writes a project-local directory marketplace, the Amber LSP
      plugin manifest, and the plugin's LSP server configuration. It merges the
      marketplace registration into .claude/settings.json and preserves other
      settings.
      HELP
    end

    def setup_command_options
    end

    def execute
      info "Setting up the Amber LSP Claude plugin..."
      list_of_updated_paths = AmberCLI::Agent::InstallClaudeAmberLSPPlugin.new.perform
      list_of_updated_paths.each { |path| info "Updated: #{path}" }
      create_default_config
      success "Amber LSP plugin setup complete."
      info "Run `amber setup:agent` to install Claude Code and Codex hooks."
    end

    private def create_default_config : Nil
      path = ".amber-lsp.yml"
      if File.exists?(path)
        warning "Skipped (exists): #{path} — remove it first to regenerate"
        return
      end

      content = <<-YAML
      # Amber LSP Configuration
      # See: https://github.com/amberframework/amber/blob/v2.0.0-beta.5/docs/guides/lsp-setup.md

      # Override built-in rule settings
      # rules:
      #   amber/controller-naming:
      #     enabled: true
      #     severity: error
      #   amber/spec-existence:
      #     severity: hint

      # Exclude directories from analysis
      exclude:
        - lib/
        - tmp/
        - db/migrations/

      # Custom project-specific rules
      # custom_rules:
      #   - id: "project/no-puts"
      #     description: "Do not use puts in production code"
      #     severity: warning
      #     applies_to: ["src/**"]
      #     pattern: '^\\s*puts\\b'
      #     message: "Avoid 'puts' in production code. Use Log.info instead."
      YAML

      File.write(path, content)
      info "Updated: #{path}"
    end
  end
end

AmberCLI::Core::CommandRegistry.register("setup:lsp", ["lsp"], AmberCLI::Commands::SetupLSPCommand)
