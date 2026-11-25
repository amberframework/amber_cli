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

  # The Grant release that `amber new` pins (tag `v0.28.0`).
  module GrantRelease
    VERSION  = "0.28.0"
    COMMIT   = "05d0ed6403b45763a9c3c346c6284a235ec8821d"
    TREE     = "0eb1ff6a7b2f1e1d1188fd4143834bae33aedf7a"
    CHECKSUM = "sha256-v2:fecb3424f0463610d863df029e3758a90bf0a85dd4574b03795014bd11af4a08"
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
