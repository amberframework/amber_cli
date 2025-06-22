# :nodoc:
module AmberCli
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}
end
