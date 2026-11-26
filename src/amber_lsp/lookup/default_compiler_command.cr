require "../../amber_cli/helpers/resolve_crystal_compiler_command"

module AmberLSP::Lookup
  # amber-lsp builds its docs index with the same compiler the amber CLI runs:
  # the command in CRYSTAL when it is set, otherwise crystal-alpha, otherwise
  # stock crystal (which builds the same index, so a Homebrew install that only
  # has crystal still answers lookups).
  def self.default_compiler_command : String
    Amber::CLI.crystal_compiler_command
  end
end
