module AmberCLI
  # The Amber release that `amber new` writes into a new application's
  # `shard.yml`, pinned by commit, and the git tree minecart must record as
  # its checksum. A release of Amber CLI that moves to a new Amber release
  # changes all three together.
  module AmberRelease
    VERSION = "2.0.0-beta.7"
    COMMIT  = "21deeec92b9253e9fc7252f994fc3465da0ffd4f"
    TREE    = "d7af4f30415f80e633c49c2d1ff0c32ac6ac7c1a"
  end
end
