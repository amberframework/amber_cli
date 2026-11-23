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

  # The Grant release that `amber new` pins (tag `v0.26.0`).
  module GrantRelease
    VERSION  = "0.26.0"
    COMMIT   = "b83a82f0261509d4ce1f26fadb318c8ba132a066"
    TREE     = "a418bd9d6e1b1b676ecc076c92eef988244ba186"
    CHECKSUM = "sha256-v2:886b86c249fa5f7ec3d4b66a0f700d8647687b3b9984b7f580cbc2c75b5306b9"
  end

  # The asset_pipeline release that `amber new` pins (tag `v0.39.0`).
  module AssetPipelineRelease
    VERSION  = "0.39.0"
    COMMIT   = "757cfca8e7b37bafe1dfe19d98192e6716e03746"
    TREE     = "12fede7cd4097c001942232dba924e3318e9a745"
    CHECKSUM = "sha256-v2:9d82b94e45c24b53f52eea129ba7cf3839d833e211e2fe3da39a03795d36efd2"
  end

  # Every release a generated application's `shard.lock` must record exactly.
  LIST_OF_PINNED_RELEASES = [
    PinnedRelease.new("amber", "Amber", AmberRelease::VERSION, AmberRelease::COMMIT, AmberRelease::TREE, AmberRelease::CHECKSUM),
    PinnedRelease.new("grant", "Grant", GrantRelease::VERSION, GrantRelease::COMMIT, GrantRelease::TREE, GrantRelease::CHECKSUM),
    PinnedRelease.new("asset_pipeline", "asset_pipeline", AssetPipelineRelease::VERSION, AssetPipelineRelease::COMMIT, AssetPipelineRelease::TREE, AssetPipelineRelease::CHECKSUM),
  ]
end
