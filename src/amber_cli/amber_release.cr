module AmberCLI
  # The Amber release that `amber new` writes into a new application's
  # `shard.yml`, pinned by commit, and the checksums Minecart must record for
  # it. A release of Amber CLI that moves to a new Amber release changes all of
  # them together.
  module AmberRelease
    VERSION = "2.0.0-beta.15"
    COMMIT  = "0830e3fdbc5e05be851c3c7ae7bf03b67be10732"
    TREE    = "5709f265e0d9e942507d5d7e155a922013b65559"
    # What Minecart 2025.11.25.9 and newer record for this tree in `shard.lock`.
    CHECKSUM = "sha256-v2:14df1ff766414599f53a8be6816023374ba01cc6a2bd6d61ad1cabb81d88ad28"
  end
end
