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

  # The Grant release that `amber new` pins (tag `v0.28.1`).
  module GrantRelease
    VERSION  = "0.28.1"
    COMMIT   = "78ad9c2c16393cff5293d79ebd05377a36aed633"
    TREE     = "083f09453d88a3bfca8acb1a7120c5655f06b501"
    CHECKSUM = "sha256-v2:30196bf9e42c04b598f9b6702496f41bae1c14f703c3767ad879352efe468fdd"
  end

  # The asset_pipeline release that `amber new` pins (tag `v0.40.1`).
  module AssetPipelineRelease
    VERSION  = "0.40.1"
    COMMIT   = "9a0447c0e10d645307e8532c7794b89491281210"
    TREE     = "89dc7d5b714fde68479653232691e9afcee387eb"
    CHECKSUM = "sha256-v2:d34f0ec99a825eb90fd651676d7aff40b3cca7277f31db9f06e0d3b1e8164e8d"
  end

  # Every release a generated application's `shard.lock` must record exactly.
  LIST_OF_PINNED_RELEASES = [
    PinnedRelease.new("amber", "Amber", AmberRelease::VERSION, AmberRelease::COMMIT, AmberRelease::TREE, AmberRelease::CHECKSUM),
    PinnedRelease.new("grant", "Grant", GrantRelease::VERSION, GrantRelease::COMMIT, GrantRelease::TREE, GrantRelease::CHECKSUM),
    PinnedRelease.new("asset_pipeline", "asset_pipeline", AssetPipelineRelease::VERSION, AssetPipelineRelease::COMMIT, AssetPipelineRelease::TREE, AssetPipelineRelease::CHECKSUM),
  ]
end
