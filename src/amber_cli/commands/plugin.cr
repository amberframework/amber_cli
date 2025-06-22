require "../core/base_command"
require "../plugins/plugin"

module AmberCLI::Commands
  class PluginCommand < AmberCLI::Core::BaseCommand
    getter plugin_name : String = ""
    getter uninstall : Bool = false
    getter plugin_args : Array(String) = [] of String

    def help_description : String
      "Generates the named plugin from the given plugin template"
    end

    def setup_command_options
      option_parser.on("-u", "--uninstall", "Uninstall plugin") do
        @parsed_options["uninstall"] = true
        @uninstall = true
      end

      option_parser.separator ""
      option_parser.separator "Usage: amber plugin [NAME] [args...] [options]"
      option_parser.separator ""
      option_parser.separator "Arguments:"
      option_parser.separator "  NAME       Name of the plugin/shard (required)"
      option_parser.separator "  args       Additional arguments available during template rendering"
      option_parser.separator ""
      option_parser.separator "Examples:"
      option_parser.separator "  amber plugin my_plugin"
      option_parser.separator "  amber plugin my_plugin arg1 arg2"
      option_parser.separator "  amber plugin my_plugin --uninstall"
    end

    def validate_arguments
      if remaining_arguments.empty?
        error "Plugin name is required"
        puts option_parser
        exit(1)
      end

      @plugin_name = remaining_arguments[0]
      @plugin_args = remaining_arguments[1..]
    end

    def execute
      if uninstall
        warning "Plugin uninstalling is currently not supported."
        exit!(error: true)
      end

      unless Amber::Plugins::Plugin.can_generate?(plugin_name)
        error "Cannot generate plugin '#{plugin_name}'"
        info "Plugin template not found or not accessible"
        exit!(error: true)
      end

      info "Generating plugin: #{plugin_name}"

      template = Amber::Plugins::Plugin.new(plugin_name, "./src/plugins", plugin_args)
      template.generate("install")

      success "Plugin '#{plugin_name}' generated successfully!"

      unless plugin_args.empty?
        info "Plugin arguments: #{plugin_args.join(", ")}"
      end
    end
  end
end

# Register the command
AmberCLI::Core::CommandRegistry.register("plugin", ["pl"], AmberCLI::Commands::PluginCommand)
