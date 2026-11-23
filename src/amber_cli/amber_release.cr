module AmberCLI
  # The Amber release that `amber new` writes into a new application's
  # `shard.yml`, pinned by commit, and the checksums Minecart must record for
  # it. A release of Amber CLI that moves to a new Amber release changes all of
  # them together.
  module AmberRelease
    VERSION = "2.0.0-beta.14"
    COMMIT  = "1a9af236afed4a6915214b8d193028e6315d7643"
    TREE    = "c38f7cc1d385178f2db65c907c4297a31e3459c3"
    # What Minecart 2025.11.25.9 and newer record for this tree in `shard.lock`.
    CHECKSUM = "sha256-v2:fd3b452154187bf99140885d5d524b8a39bdd5771338d9c18e3bb0b8f8feab75"
  end
end
