# :nodoc:
require "yaml"
require "./process_runner"

# Sentry module provides file watching and process management for Amber CLI
# This is used by the watch command to automatically rebuild and restart 
# the application when source files change.
module Sentry
  # ProcessRunner handles the actual file watching and process management
  # It's used by the watch command to monitor files and restart processes
  # when changes are detected.
end
