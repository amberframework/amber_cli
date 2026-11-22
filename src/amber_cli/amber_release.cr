module AmberCLI
  # The Amber release that `amber new` writes into a new application's
  # `shard.yml`, pinned by commit, and the checksums Minecart must record for
  # it. A release of Amber CLI that moves to a new Amber release changes all of
  # them together.
  module AmberRelease
    VERSION = "2.0.0-beta.12"
    COMMIT  = "834ef5d2790a1486b4c879e1b87ecd0c32e7809a"
    TREE    = "c07e799f09b91f002ca07e8f31c4dfc054e82fc4"
    # What Minecart 2025.11.25.9 and newer record for this tree in `shard.lock`.
    CHECKSUM = "sha256-v2:e54b07880db48f675951fc3d29221c97e3bed867d777972962d3b750ca6dfe5b"
  end
end
