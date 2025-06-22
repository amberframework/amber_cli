# :nodoc:
module AmberCli
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}
end

# :nodoc:
# Legacy compatibility - completely hidden from documentation
# module Amber
#   VERSION = AmberCli::VERSION
# end
