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
    COMMIT   = "bf9cb490695860b08f209989be686a0eb42c1019"
    TREE     = "17ddebfc2afb76051b13ab46c218fd605487f52c"
    CHECKSUM = "sha256-v2:b736ee17d0fdce23740bd768089085ecb776b3f8ae308cd058132aff25fa4c77"
  end

  # The asset_pipeline release that `amber new` pins (tag `v0.40.1`).
  module AssetPipelineRelease
    VERSION  = "0.40.1"
    COMMIT   = "dc2185094f4da66062e4e7fb65fb41a9e46a1287"
    TREE     = "2ba60af749a7a1250a3a770b67230f57b31c02ef"
    CHECKSUM = "sha256-v2:ce5ff984b86dcdcedd3cbd51aab51e1b59be52273c29a18e69dc30015b8bf50e"
  end

  # Every release a generated application's `shard.lock` must record exactly.
  LIST_OF_PINNED_RELEASES = [
    PinnedRelease.new("amber", "Amber", AmberRelease::VERSION, AmberRelease::COMMIT, AmberRelease::TREE, AmberRelease::CHECKSUM),
    PinnedRelease.new("grant", "Grant", GrantRelease::VERSION, GrantRelease::COMMIT, GrantRelease::TREE, GrantRelease::CHECKSUM),
    PinnedRelease.new("asset_pipeline", "asset_pipeline", AssetPipelineRelease::VERSION, AssetPipelineRelease::COMMIT, AssetPipelineRelease::TREE, AssetPipelineRelease::CHECKSUM),
  ]
end
