module AmberCLI
  # The Amber release that `amber new` writes into a new application's
  # `shard.yml`, pinned by commit, and the checksums Minecart must record for
  # it. A release of Amber CLI that moves to a new Amber release changes all of
  # them together.
  module AmberRelease
    VERSION = "2.0.0-beta.10"
    COMMIT  = "d291e0930dd22b14a2d10f75a9de063abb0e64e4"
    TREE    = "fb4574c6b15b60357abd43ed0a1a8d7a0957e574"
    # What Minecart 2025.11.25.9 and newer record for this tree in `shard.lock`.
    CHECKSUM = "sha256-v2:8d354db3b41625db0362162a34836fe10a8b11a378f3837d34cc6bbcece1cb94"
  end
end
