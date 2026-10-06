require "digest/sha256"
path = "input.txt"
digest = Digest::SHA256.new
digest.file(path)
digest.hexfinal
