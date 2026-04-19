# :nodoc:
require "../version"
require "./config"

module Amber::CLI
  include Amber::Environment

  def self.toggle_colors(on_off)
    Colorize.enabled = !on_off
  end

  # Legacy CLI implementation - replaced by new command architecture
  # This module is kept for backward compatibility during refactoring
end
