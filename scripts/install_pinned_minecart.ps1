$ErrorActionPreference = "Stop"

$minecartCommit = "091e8e2da15a0a4885a40b174d5a561da0201c1b"
$minecartTree = "2d00f70352d6ff70b29b1037bc85a316a6a13117"
$installRoot = Join-Path $env:RUNNER_TEMP "amber-pinned-minecart"

New-Item -ItemType Directory -Force $installRoot | Out-Null
& git -C $installRoot init -q
& git -C $installRoot remote add origin https://github.com/crimson-knight/shards.git
& git -C $installRoot fetch --depth=1 origin $minecartCommit
if ($LASTEXITCODE -ne 0) { throw "Could not fetch the pinned Minecart commit" }
& git -C $installRoot checkout -q --detach FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Could not check out the pinned Minecart commit" }

$actualCommit = (& git -C $installRoot rev-parse HEAD).Trim()
$actualTree = (& git -C $installRoot rev-parse 'HEAD^{tree}').Trim()
if ($actualCommit -ne $minecartCommit -or $actualTree -ne $minecartTree) {
  throw "Minecart commit or tree hash did not match the pin"
}

Push-Location $installRoot
try {
  New-Item -ItemType Directory -Force bin | Out-Null
  & crystal build src/shards.cr -o bin/minecart.exe
  if ($LASTEXITCODE -ne 0) { throw "Minecart build failed" }
  $minecartVersion = (& ./bin/minecart.exe --version).Trim()
  if ($minecartVersion -notlike "Minecart 2025.11.25.7*") {
    throw "Built Minecart version did not match the pin: $minecartVersion"
  }
} finally {
  Pop-Location
}

"$(Join-Path $installRoot 'bin')" >> $env:GITHUB_PATH
