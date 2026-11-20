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

  # The Grant release that `amber new` pins (tag `v0.24.0`).
  module GrantRelease
    VERSION  = "0.24.0"
    COMMIT   = "7bb4b9d45e74c490e6f3ad80cef8cc1cebd5b889"
    TREE     = "ac01af3a3edb7d881c798c755e0845ad04383225"
    CHECKSUM = "sha256-v2:0c295bd9da92146c5482c63326adb402b24e33c152af86025a27f9da1a086f51"
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
