require "./amber_release"

module AmberCLI
  # One shard release that `amber new` writes into a new application's
  # `shard.yml`, pinned by commit, with the checksums Minecart must record for
  # it: `checksum` from Minecart 2025.11.25.9 and newer, and `git-tree:<tree>`
  # from an older Minecart.
  record PinnedRelease,
    shard_name : String,
    display_name : String,
    version : String,
    commit : String,
    tree : String,
    checksum : String

  # The Grant release that `amber new` pins (tag `v0.25.0`).
  module GrantRelease
    VERSION  = "0.25.0"
    COMMIT   = "eb55ebd1ce1c7011b08288cc3e9e943581bea77f"
    TREE     = "feb59c2da5b67dd21e12b8d26f7c45baddb39ec3"
    CHECKSUM = "sha256-v2:6296051f79683e5f70d549d6a5fa947e6300d68b85004746e0df5bcca47840a1"
  end

  # The asset_pipeline release that `amber new` pins (tag `v0.38.0`).
  module AssetPipelineRelease
    VERSION  = "0.38.0"
    COMMIT   = "73c89c3417a5282d9ac4179b283bcc660b7f898a"
    TREE     = "42caf3fc2d1af5e97417e7d7947dddd025e405e1"
    CHECKSUM = "sha256-v2:80ea8ac95943a3c5be438e68c2ef2f00d9b9783f0787fcd67ef346f135d9510c"
  end

  # Every release a generated application's `shard.lock` must record exactly.
  LIST_OF_PINNED_RELEASES = [
    PinnedRelease.new("amber", "Amber", AmberRelease::VERSION, AmberRelease::COMMIT, AmberRelease::TREE, AmberRelease::CHECKSUM),
    PinnedRelease.new("grant", "Grant", GrantRelease::VERSION, GrantRelease::COMMIT, GrantRelease::TREE, GrantRelease::CHECKSUM),
    PinnedRelease.new("asset_pipeline", "asset_pipeline", AssetPipelineRelease::VERSION, AssetPipelineRelease::COMMIT, AssetPipelineRelease::TREE, AssetPipelineRelease::CHECKSUM),
  ]
end
