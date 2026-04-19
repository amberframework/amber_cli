require "../core/base_command"

# The `setup:lsp` command configures the Amber LSP server for Claude Code
# integration in an Amber project directory.
#
# ## Usage
# ```
# amber setup: lsp [OPTIONS]
# ```
#
# ## What It Does
# 1. Resolves or builds the `amber-lsp` binary
# 2. Creates `.lsp.json` for Claude Code LSP server discovery
# 3. Creates `.claude-plugin/plugin.json` as the plugin manifest
# 4. Creates `.amber-lsp.yml` with default rule configuration
#
# ## Examples
# ```
# amber setup:lsp
# amber setup:lsp --binary-path=/usr/local/bin/amber-lsp
# amber setup:lsp --skip-build
# ```
module AmberCLI::Commands
  class SetupLSPCommand < AmberCLI::Core::BaseCommand
    getter binary_path_option : String? = nil
    getter is_skip_build : Bool = false

    def help_description : String
      <<-HELP
      Set up the Amber LSP server for Claude Code integration

      Usage: amber setup:lsp [OPTIONS]

      This command:
        1. Builds the amber-lsp binary (if needed)
        2. Creates .lsp.json for Claude Code LSP discovery
        3. Creates .claude-plugin/plugin.json
        4. Creates .amber-lsp.yml with default configuration

      Options:
        --binary-path=PATH  Path to pre-built amber-lsp binary
        --skip-build        Skip building the binary (assume it's on PATH)
      HELP
    end

    def setup_command_options
      option_parser.separator ""
      option_parser.separator "Options:"

      option_parser.on("--binary-path=PATH", "Path to pre-built amber-lsp binary") do |path|
        @binary_path_option = path
      end

      option_parser.on("--skip-build", "Skip building the binary (assume it's on PATH)") do
        @is_skip_build = true
      end
    end

    def execute
      info "Setting up Amber LSP for Claude Code..."

      binary_path = resolve_binary_path

      create_lsp_json(binary_path)
      create_plugin_json
      create_default_config

      success "Amber LSP setup complete!"
      puts ""
      info "Files created:"
      info "  .lsp.json              - LSP server configuration"
      info "  .claude-plugin/plugin.json - Claude Code plugin manifest"
      info "  .amber-lsp.yml         - Rule configuration (customize as needed)"
      puts ""
      info "The LSP will activate automatically when you start Claude Code in this directory."
    end

    private def resolve_binary_path : String
      # 1. Check --binary-path option first
      if path = binary_path_option
        unless File.exists?(path)
          error "Specified binary not found: #{path}"
          exit(1)
        end
        return File.expand_path(path)
      end

      # 2. Check if amber-lsp is on PATH
      if found = Process.find_executable("amber-lsp")
        info "Found amber-lsp on PATH: #{found}"
        return found
      end

      # 3. Check if we're in the amber_cli project and binary exists
      cli_project_root = find_cli_project_root
      if cli_project_root
        existing_binary = File.join(cli_project_root, "bin", "amber-lsp")
        if File.exists?(existing_binary)
          info "Found amber-lsp binary: #{existing_binary}"
          return existing_binary
        end
      end

      # 4. If --skip-build is set, use bare command name
      if is_skip_build
        warning "Skipping build. Assuming 'amber-lsp' is available on PATH at runtime."
        return "amber-lsp"
      end

      # 5. Try to build it if source is available
      if cli_project_root && File.exists?(File.join(cli_project_root, "src", "amber_lsp.cr"))
        build_binary(cli_project_root)
      else
        error "Could not find or build amber-lsp binary."
        error "Options:"
        error "  1. Run this command from the amber_cli project directory"
        error "  2. Use --binary-path=PATH to specify an existing binary"
        error "  3. Use --skip-build to assume amber-lsp is on PATH"
        exit(1)
      end
    end

    private def find_cli_project_root : String?
      # Check if the current directory is the amber_cli project
      if File.exists?("src/amber_lsp.cr")
        return Dir.current
      end

      # Check the known development location
      dev_path = File.expand_path("~/open_source_coding_projects/amber_cli")
      if File.exists?(File.join(dev_path, "src", "amber_lsp.cr"))
        return dev_path
      end

      nil
    end

    private def build_binary(cli_project_root : String) : String
      binary_path = File.join(cli_project_root, "bin", "amber-lsp")
      source_path = File.join(cli_project_root, "src", "amber_lsp.cr")

      info "Building amber-lsp from source..."
      info "  Source: #{source_path}"
      info "  Output: #{binary_path}"

      Dir.mkdir_p(File.join(cli_project_root, "bin")) unless Dir.exists?(File.join(cli_project_root, "bin"))

      process = Process.run(
        "crystal",
        ["build", source_path, "-o", binary_path, "--release"],
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )

      unless process.success?
        error "Failed to build amber-lsp binary"
        exit(1)
      end

      success "Built amber-lsp successfully"
      binary_path
    end

    private def create_lsp_json(binary_path : String)
      lsp_config = {
        "amber" => {
          "command"             => binary_path,
          "args"                => [] of String,
          "extensionToLanguage" => {
            ".cr" => "crystal",
          },
          "transport"      => "stdio",
          "restartOnCrash" => true,
          "maxRestarts"    => 3,
        },
      }

      path = ".lsp.json"
      if File.exists?(path)
        warning "Overwriting existing #{path}"
      end
      File.write(path, lsp_config.to_pretty_json + "\n")
      info "Created: #{path}"
    end

    private def create_plugin_json
      dir = ".claude-plugin"
      Dir.mkdir_p(dir) unless Dir.exists?(dir)

      plugin_config = {
        "name"        => "amber-framework-lsp",
        "version"     => "1.0.0",
        "description" => "Convention diagnostics for Amber V2 web framework projects.",
        "author"      => {
          "name" => "Amber Framework",
        },
        "homepage"   => "https://github.com/amberframework/amber",
        "lspServers" => "./.lsp.json",
      }

      path = File.join(dir, "plugin.json")
      if File.exists?(path)
        warning "Overwriting existing #{path}"
      end
      File.write(path, plugin_config.to_pretty_json + "\n")
      info "Created: #{path}"
    end

    private def create_default_config
      path = ".amber-lsp.yml"
      if File.exists?(path)
        warning "Skipped (exists): #{path} — remove it first to regenerate"
        return
      end

      content = <<-YAML
      # Amber LSP Configuration
      # See: https://docs.amberframework.org/amber/guides/lsp

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
      info "Created: #{path}"
    end
  end
end

# Register the command
AmberCLI::Core::CommandRegistry.register("setup:lsp", ["lsp"], AmberCLI::Commands::SetupLSPCommand)
