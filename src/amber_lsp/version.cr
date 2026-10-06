module AmberLSP
  VERSION = "1.0.0"

  # The amber_cli release this server ships in, read from shard.yml at compile time.
  # Minecart is preferred; shards-alpha or shards answers when Minecart is not installed.
  RELEASE = {{ `minecart version "#{__DIR__}/../.." 2>/dev/null || shards-alpha version "#{__DIR__}/../.." 2>/dev/null || shards version "#{__DIR__}/../.."`.chomp.stringify.downcase }}

  # The git commit the binary was built from, or "unknown" outside a git checkout.
  BUILD_COMMIT = {{ `git -C "#{__DIR__}" rev-parse --short=12 HEAD 2>/dev/null || echo unknown`.chomp.stringify }}

  # Printed by `amber-lsp --help`. With no arguments amber-lsp runs the language server on stdin.
  USAGE = <<-TEXT
  Usage:
    amber-lsp                     run the language server over stdin and stdout (editors start this)
    amber-lsp lookup QUERY        look up a Crystal API: Type.method, Type#method, or Type
    amber-lsp hint                read compiler output on stdin and print matching API card hints
    amber-lsp --check FILE.cr     check one file with the Amber V2 rules
    amber-lsp context [--root DIR] print the library rule packs detected for this project
    amber-lsp --version           print the build: version, amber_cli release, commit

  Add --help after lookup, hint, or context for its options.
  Guide: https://github.com/amberframework/amber_cli/blob/main/docs/guides/ai-assistants.md
  TEXT

  # One line that identifies this exact build, printed by `amber-lsp --version`.
  def self.version_line : String
    "amber-lsp #{VERSION} (amber_cli #{RELEASE}, commit #{BUILD_COMMIT})"
  end
end
