module AmberCLI
  # The Amber release that `amber new` writes into a new application's
  # `shard.yml`, pinned by commit, and the checksums Minecart must record for
  # it. A release of Amber CLI that moves to a new Amber release changes all of
  # them together.
  module AmberRelease
    VERSION = "2.0.0-beta.10"
    COMMIT  = "d775841a0af43bf512f1c9b704906fccdf8863f7"
    TREE    = "e06f26daef02a30e91114b2c71224920e0c097de"
    # What Minecart 2025.11.25.9 and newer record for this tree in `shard.lock`.
    CHECKSUM = "sha256-v2:e1099a4f7a25db316b2abdf80f999a2753a0fcc056834f3abe6d9b5a88ae945d"
  end
end
