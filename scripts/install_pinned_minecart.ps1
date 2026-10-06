$ErrorActionPreference = "Stop"

$minecartCommit = "0ffac921c68774ea143aeaa83c369d0a38c2d3e5"
$minecartTree = "f0e8a69bffe22afd0cee9b24994bde629384f093"
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
  if ($minecartVersion -notlike "Minecart 2025.11.25.8*") {
    throw "Built Minecart version did not match the pin: $minecartVersion"
  }
} finally {
  Pop-Location
}

"$(Join-Path $installRoot 'bin')" >> $env:GITHUB_PATH
