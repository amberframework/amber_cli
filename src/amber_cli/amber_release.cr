module AmberCLI
  # The Amber release that `amber new` writes into a new application's
  # `shard.yml`, pinned by commit, and the checksums Minecart must record for
  # it. A release of Amber CLI that moves to a new Amber release changes all of
  # them together.
  module AmberRelease
    VERSION = "2.0.0-beta.11"
    COMMIT  = "f987f1bb19b789f8f14b000b6ee00ed496fe6cbb"
    TREE    = "fc2433e6cf3b55fc779977cc70b1270c7910c920"
    # What Minecart 2025.11.25.9 and newer record for this tree in `shard.lock`.
    CHECKSUM = "sha256-v2:732bd8a19fed53e2e8ef0ee768dab03466abf502324d55de5f81961ac75456fa"
  end
end
