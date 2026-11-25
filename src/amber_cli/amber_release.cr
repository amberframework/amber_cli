module AmberCLI
  # The Amber release that `amber new` writes into a new application's
  # `shard.yml`, pinned by commit, and the checksums Minecart must record for
  # it. A release of Amber CLI that moves to a new Amber release changes all of
  # them together.
  module AmberRelease
    VERSION = "2.0.0-beta.16"
    COMMIT  = "261cf2d3b4a6f3292fefb8113e71e0fe6900fcee"
    TREE    = "9a6e713abbdcc8500d0d6ffd71b7383952f6c038"
    # What Minecart 2025.11.25.9 and newer record for this tree in `shard.lock`.
    CHECKSUM = "sha256-v2:9f7aa2e42de37b244efe33afa66c2f60177ba0d82968afc6ac2f728a3f978e77"
  end
end
