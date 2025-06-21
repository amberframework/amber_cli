require "log"
require "cli"
require "./version"
require "./exceptions/*"
require "./environment"
require "./amber_cli/commands"

# New core architecture modules
require "./amber_cli/exceptions"
require "./amber_cli/core/word_transformer"
require "./amber_cli/core/generator_config"
require "./amber_cli/core/template_engine"
require "./amber_cli/core/base_command"
require "./amber_cli/core/configurable_generator_manager"

backend = Log::IOBackend.new
backend.formatter = Log::Formatter.new do |entry, io|
  io << entry.timestamp.to_s("%I:%M:%S")
  io << " "
  io << entry.source
  io << " (#{entry.severity})" if entry.severity > Log::Severity::Debug
  io << " "
  io << entry.message
end
Log.builder.bind "*", :info, backend

AmberCLI::MainCommand.run ARGV
