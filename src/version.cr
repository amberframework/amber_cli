# :nodoc:
module AmberCli
  # Minecart is preferred; shards-alpha or shards answers when Minecart is not installed.
  VERSION = {{ `minecart version "#{__DIR__}" 2>/dev/null || shards-alpha version "#{__DIR__}" 2>/dev/null || shards version "#{__DIR__}"`.chomp.stringify.downcase }}
end
