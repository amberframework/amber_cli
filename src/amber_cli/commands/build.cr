require "yaml"
require "../core/base_command"
require "../core/target_tier"
require "../config"
require "../helpers/resolve_crystal_compiler_command"
require "../static_assets"

# The `build` command compiles the application's release binary with
# crystal-alpha.
#
# ## Usage
# ```
# amber build [options]
# ```
#
# ## Options
# - `-t, --target-tier=NAME` - CPU tier to build for (default: portable)
# - `--list-target-tiers` - Print every tier and the machines it fits
# - `--dry-run` - Print the compiler command without running it
#
# ## Examples
# ```
# # Portable binary: runs on every supported chip
# amber build
#
# # Tuned for the machine you deploy to
# amber build --target-tier x86-64-v3
# ```
module AmberCLI::Commands
  class BuildCommand < AmberCLI::Core::BaseCommand
    # The `targets:` entries of shard.yml, which name the app's entry point.
    struct ShardTargets
      include YAML::Serializable

      struct Target
        include YAML::Serializable

        getter main : String
      end

      getter targets : Hash(String, Target) = {} of String => Target
    end

    getter target_tier_name : String? = nil
    getter? list_target_tiers : Bool = false
    getter? dry_run : Bool = false

    def help_description : String
      "Builds the application's release binary with crystal-alpha"
    end

    def setup_command_options
      option_parser.on("-t NAME", "--target-tier=NAME", "CPU tier to build for (default: portable)") do |tier_name|
        @parsed_options["target_tier"] = tier_name
        @target_tier_name = tier_name
      end

      option_parser.on("--list-target-tiers", "Print every target tier and the machines it fits") do
        @parsed_options["list_target_tiers"] = true
        @list_target_tiers = true
      end

      option_parser.on("--dry-run", "Print the compiler command without running it") do
        @parsed_options["dry_run"] = true
        @dry_run = true
      end

      option_parser.separator ""
      option_parser.separator "Usage: amber build [options]"
      option_parser.separator ""
      option_parser.separator "The binary is written to bin/<target> from the first target in shard.yml."
      option_parser.separator "A `build: target_tier:` entry in .amber.yml sets the tier when --target-tier is not given."
      option_parser.separator ""
      option_parser.separator "Examples:"
      option_parser.separator "  amber build"
      option_parser.separator "  amber build --target-tier x86-64-v3"
      option_parser.separator "  amber build --list-target-tiers"
    end

    def execute
      if list_target_tiers?
        puts AmberCLI.target_tier_table
        return
      end

      tier = selected_target_tier
      list_of_arguments = compiler_arguments(tier)
      info "Target tier: #{tier.tier_name} (#{tier.description})"
      info "Build command: #{Process.quote([compiler_command] + list_of_arguments)}"
      return if dry_run?

      build_static_assets
      Dir.mkdir_p(File.dirname(output_path))
      status = Process.run(compiler_command, list_of_arguments, output: :inherit, error: :inherit)
      unless status.success?
        error "crystal-alpha build failed (exit #{status.exit_code})"
        exit!(error: true)
      end
      success "Built #{output_path} for target tier #{tier.tier_name}"
    rescue ex : AmberCLI::UnknownTargetTierError | AmberCLI::TargetTierArchitectureError
      error ex.message || "Invalid target tier"
      exit!(error: true)
    rescue ex : AssetPipeline::StaticAssets::Error
      error ex.message || "Static asset build failed"
      exit!(error: true)
    end

    # Returns the tier from --target-tier, else from .amber.yml, else portable.
    def selected_target_tier(host_architecture : String = AmberCLI::Commands::BuildCommand.host_architecture) : AmberCLI::TargetTier
      tier_name = target_tier_name || Amber::CLI.config.build.target_tier || AmberCLI::DEFAULT_TARGET_TIER_NAME
      tier = AmberCLI.find_target_tier!(tier_name)
      unless tier.builds_on?(host_architecture)
        raise AmberCLI::TargetTierArchitectureError.new(
          "Target tier '#{tier.tier_name}' is for #{tier.architecture} machines and this machine is #{host_architecture}. " \
          "Run `amber build --target-tier #{tier.tier_name}` on an #{tier.architecture} machine (your deploy host or CI).")
      end
      tier
    end

    # Returns the compiler arguments (everything after the compiler name).
    def compiler_arguments(tier : AmberCLI::TargetTier) : Array(String)
      ["build", entry_point, "-o", output_path, "--release"] + tier.list_of_compiler_flags
    end

    def compiler_command : String
      Amber::CLI.crystal_compiler_command
    end

    def entry_point : String
      if target = first_shard_target
        return target[1].main
      end
      "src/#{Amber::CLI::Config.get_name}.cr"
    end

    def output_path : String
      if target = first_shard_target
        return "bin/#{target[0]}"
      end
      "bin/#{Amber::CLI::Config.get_name}"
    end

    # Returns the architecture of the machine running the CLI.
    def self.host_architecture : String
      {% if flag?(:x86_64) %}
        "x86_64"
      {% elsif flag?(:aarch64) %}
        "aarch64"
      {% else %}
        "unknown"
      {% end %}
    end

    private def first_shard_target : Tuple(String, ShardTargets::Target)?
      return nil unless File.exists?(Amber::CLI::Config::SHARD_YML)
      ShardTargets.from_yaml(File.read(Amber::CLI::Config::SHARD_YML)).targets.first?
    end

    private def build_static_assets : Nil
      return unless Dir.exists?(AmberCLI::StaticAssets::SOURCE_ROOT.to_s)
      manifest = AmberCLI::StaticAssets.build
      info "Compiled #{manifest.assets.size} fingerprinted static assets"
    end
  end
end

AmberCLI::Core::CommandRegistry.register("build", ["b"], AmberCLI::Commands::BuildCommand)
