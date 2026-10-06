# :nodoc:
module AmberCli
  VERSION = {{ `minecart version "#{__DIR__}"`.chomp.stringify.downcase }}
end
