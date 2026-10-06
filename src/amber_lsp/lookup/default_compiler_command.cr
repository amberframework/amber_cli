module AmberLSP::Lookup
  # crystal-alpha is preferred. Stock crystal builds the same docs index, so a
  # Homebrew install that only has crystal still answers lookups.
  def self.default_compiler_command : String
    Process.find_executable("crystal-alpha") ? "crystal-alpha" : "crystal"
  end
end
