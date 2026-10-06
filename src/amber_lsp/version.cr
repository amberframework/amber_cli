module AmberLSP
  VERSION = "1.0.0"

  # The amber_cli release this server ships in, read from shard.yml at compile time.
  RELEASE = {{ `minecart version "#{__DIR__}/../.."`.chomp.stringify.downcase }}

  # The git commit the binary was built from, or "unknown" outside a git checkout.
  BUILD_COMMIT = {{ `git -C "#{__DIR__}" rev-parse --short=12 HEAD 2>/dev/null || echo unknown`.chomp.stringify }}

  # One line that identifies this exact build, printed by `amber-lsp --version`.
  def self.version_line : String
    "amber-lsp #{VERSION} (amber_cli #{RELEASE}, commit #{BUILD_COMMIT})"
  end
end
