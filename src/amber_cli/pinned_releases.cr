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

  # The Grant release that `amber new` pins (tag `v0.25.1`).
  module GrantRelease
    VERSION  = "0.25.1"
    COMMIT   = "cfb9ff4a48e28c78040c37c1ffbb05379df26d97"
    TREE     = "9bdf0c29956f5fef8a0ffff429e2946289fd8d90"
    CHECKSUM = "sha256-v2:432b5fc89aa21041d4d6a1dc29784ca10bd205d706348b71d589c0247db0a757"
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
