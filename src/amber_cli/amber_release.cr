module AmberCLI
  # The Amber release that `amber new` writes into a new application's
  # `shard.yml`, pinned by commit, and the checksums Minecart must record for
  # it. A release of Amber CLI that moves to a new Amber release changes all of
  # them together.
  module AmberRelease
    VERSION = "2.0.0-beta.16"
    COMMIT  = "e5c4ac7f0c1d908c3f3ad9ea4f33d858e1f47a5f"
    TREE    = "0a9b08f41717679b07b7d8030feebcce28f9012d"
    # What Minecart 2025.11.25.9 and newer record for this tree in `shard.lock`.
    CHECKSUM = "sha256-v2:b1d2dbc03a48dd16d3d11d078d96d9680f0e5416fdbb5d6a212f52964cd93763"
  end
end
