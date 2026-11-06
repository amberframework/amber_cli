module AmberCLI
  # The Amber release that `amber new` writes into a new application's
  # `shard.yml`, pinned by commit, and the git tree minecart must record as
  # its checksum. A release of Amber CLI that moves to a new Amber release
  # changes all three together.
  module AmberRelease
    VERSION = "2.0.0-beta.9"
    COMMIT  = "34a93352eaa89501d24e2b9ff90b058209a22720"
    TREE    = "f1e7332d02229aec58ab5303ade7fc6c9d14fcee"
  end
end
