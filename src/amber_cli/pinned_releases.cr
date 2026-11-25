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

  # The Grant release that `amber new` pins (tag `v0.27.0`).
  module GrantRelease
    VERSION  = "0.27.0"
    COMMIT   = "f89a84c355ffa95f21232a887cc58a5b5e91ef8b"
    TREE     = "c0f4ac8d32df2fff012a21e280b741af439047a0"
    CHECKSUM = "sha256-v2:72dfd31da5b7865f5977dd00b21dfa91b2f08eb83972f5d6fec8d283f0ae31d9"
  end

  # The asset_pipeline release that `amber new` pins (tag `v0.40.0`).
  module AssetPipelineRelease
    VERSION  = "0.40.0"
    COMMIT   = "84f3188239e43dc6e0bcfd2e72074e8ec67156cd"
    TREE     = "a9ff8d2bdc88044ce6bf254b5ccbd6943365bdfb"
    CHECKSUM = "sha256-v2:137195ff733af93d36787d4a965a1846bb4795347a6eced8a5dd3f015ee729b9"
  end

  # Every release a generated application's `shard.lock` must record exactly.
  LIST_OF_PINNED_RELEASES = [
    PinnedRelease.new("amber", "Amber", AmberRelease::VERSION, AmberRelease::COMMIT, AmberRelease::TREE, AmberRelease::CHECKSUM),
    PinnedRelease.new("grant", "Grant", GrantRelease::VERSION, GrantRelease::COMMIT, GrantRelease::TREE, GrantRelease::CHECKSUM),
    PinnedRelease.new("asset_pipeline", "asset_pipeline", AssetPipelineRelease::VERSION, AssetPipelineRelease::COMMIT, AssetPipelineRelease::TREE, AssetPipelineRelease::CHECKSUM),
  ]
end
