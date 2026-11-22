module AmberCLI
  # The Amber release that `amber new` writes into a new application's
  # `shard.yml`, pinned by commit, and the checksums Minecart must record for
  # it. A release of Amber CLI that moves to a new Amber release changes all of
  # them together.
  module AmberRelease
    VERSION = "2.0.0-beta.13"
    COMMIT  = "346ce766853d3916f3cf1d391921dafb907615bd"
    TREE    = "cd384f403c3aea50783f63d3a14b383d037065f4"
    # What Minecart 2025.11.25.9 and newer record for this tree in `shard.lock`.
    CHECKSUM = "sha256-v2:b2087f907b51e65f5e6a1af36a663408fb5383d127377e35c2fbf0c0a735a11e"
  end
end
