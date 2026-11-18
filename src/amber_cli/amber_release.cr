module AmberCLI
  # The Amber release that `amber new` writes into a new application's
  # `shard.yml`, pinned by commit, and the checksums Minecart must record for
  # it. A release of Amber CLI that moves to a new Amber release changes all of
  # them together.
  #
  # INTEGRATION PINS (beta.11): COMMIT, TREE and CHECKSUM point at the head of
  # amberframework/amber#1451 so the regex-free Grant and asset_pipeline
  # branches can be proven together. Before this branch merges they become the
  # tagged v2.0.0-beta.11 commit, its tree and its Minecart checksum, and
  # VERSION becomes "2.0.0-beta.11".
  module AmberRelease
    VERSION = "2.0.0-beta.10"
    COMMIT  = "43a361419514b49388d5716c97e5b95d170ba5a8"
    TREE    = "332d04b4e88fc045f4b0784157eea21e33297b42"
    # What Minecart 2025.11.25.9 and newer record for this tree in `shard.lock`.
    CHECKSUM = "sha256-v2:f58fc614bc2c719985a1ca0bae9a206c75d57a42ef75fe8781116d45b9e88ba7"
  end
end
