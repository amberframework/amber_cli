param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Cli,
  [Parameter(Position = 1)]
  [string]$FrameworkCommit = ""
)

$ErrorActionPreference = "Stop"

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Command,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
  )

  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Command failed with exit code $LASTEXITCODE"
  }
}

$cliPath = (Resolve-Path $Cli).Path
$smokeRoot = Join-Path $env:RUNNER_TEMP "amber-v2-windows-smoke"
$appPath = Join-Path $smokeRoot "amber_beta_smoke"

if (Test-Path $smokeRoot) {
  Remove-Item -Recurse -Force $smokeRoot
}
New-Item -ItemType Directory -Force $smokeRoot | Out-Null

Invoke-Checked -Command $cliPath -Arguments @("new", $appPath, "--type", "web", "--no-deps")

$shardPath = Join-Path $appPath "shard.yml"
$amberConfigPath = Join-Path $appPath ".amber.yml"
$manifest = [System.IO.File]::ReadAllText($shardPath)
$amberConfig = [System.IO.File]::ReadAllText($amberConfigPath)

if (-not $manifest.Contains("github: crimson-knight/grant")) {
  throw "Generated shard.yml does not include Grant"
}
if (-not $manifest.Contains("github: crystal-lang/crystal-sqlite3")) {
  throw "Generated shard.yml does not include SQLite"
}
if (-not $manifest.Contains("github: amberframework/asset_pipeline")) {
  throw "Generated shard.yml does not include Asset Pipeline"
}
if (-not $amberConfig.Contains("database: sqlite") -or -not $amberConfig.Contains("model: grant")) {
  throw "Generated .amber.yml does not select SQLite and Grant"
}

if ($FrameworkCommit) {
  $releasedFramework = "    version: 2.0.0-beta.3"
  if (-not $manifest.Contains($releasedFramework)) {
    throw "Generated shard.yml does not contain the expected Amber beta pin"
  }
  $manifest = $manifest.Replace(
      "    github: amberframework/amber",
      "    github: crimson-knight/amber"
    ).Replace(
      $releasedFramework,
      "    commit: $FrameworkCommit"
    )
  [System.IO.File]::WriteAllText($shardPath, $manifest)
}

Push-Location $appPath
try {
  Invoke-Checked -Command $cliPath -Arguments @("assets", "check")
  Invoke-Checked -Command "shards" -Arguments @("install")
  Invoke-Checked -Command $cliPath -Arguments @("assets", "build")
  Invoke-Checked -Command $cliPath -Arguments @("assets", "check")

  $assetManifestPath = Join-Path $appPath "public/assets/manifest.json"
  if (-not (Test-Path $assetManifestPath)) {
    throw "Generated app did not produce an asset manifest"
  }
  $assetManifest = [System.IO.File]::ReadAllText($assetManifestPath) | ConvertFrom-Json
  $css = $assetManifest.assets.'stylesheets/app.css'
  $javascript = $assetManifest.assets.'javascript/app.js'
  $logo = $assetManifest.assets.'images/amber-crystal.svg'
  $favicon = $assetManifest.assets.'images/favicon.svg'
  foreach ($entry in @($css, $javascript, $logo, $favicon)) {
    if (-not $entry.path -or -not $entry.integrity.StartsWith("sha256-")) {
      throw "Asset manifest entry is missing its path or integrity"
    }
    $relativeAssetPath = $entry.path.TrimStart([char[]]@('/'))
    $compiledPath = Join-Path (Join-Path $appPath "public") $relativeAssetPath
    if (-not (Test-Path $compiledPath)) {
      throw "Compiled asset is missing: $compiledPath"
    }
  }
  $relativeCssPath = $css.path.TrimStart([char[]]@('/'))
  $compiledCssPath = Join-Path (Join-Path $appPath "public") $relativeCssPath
  if (-not ([System.IO.File]::ReadAllText($compiledCssPath).Contains($logo.path))) {
    throw "Compiled CSS did not rewrite the authored logo URL"
  }
  if (Test-Path (Join-Path $appPath "public/css/app.css")) {
    throw "Generated app still contains a raw public CSS entry point"
  }

  Invoke-Checked -Command "crystal" -Arguments @("spec")
  Invoke-Checked -Command $cliPath -Arguments @(
    "generate",
    "scaffold",
    "Pet",
    "name:string:required",
    "species:string:required",
    "adopted:bool"
  )

  $routesPath = Join-Path $appPath "config/routes.cr"
  $routes = [System.IO.File]::ReadAllText($routesPath)
  if (-not $routes.Contains('resources "/pets", PetController')) {
    throw "Generated scaffold did not add the Pet resource route"
  }

  $previousAmberEnv = $env:AMBER_ENV
  try {
    $env:AMBER_ENV = "test"
    Invoke-Checked -Command $cliPath -Arguments @("database", "migrate")
  } finally {
    $env:AMBER_ENV = $previousAmberEnv
  }

  # Request specs use Amber's default development environment unless the
  # caller sets AMBER_ENV. Mirror the Unix smoke test and migrate both stores.
  Invoke-Checked -Command $cliPath -Arguments @("database", "migrate")

  Invoke-Checked -Command "crystal" -Arguments @("spec")
  Invoke-Checked -Command $cliPath -Arguments @("assets", "build")
  Invoke-Checked -Command $cliPath -Arguments @("assets", "check")
  New-Item -ItemType Directory -Force bin | Out-Null
  Invoke-Checked -Command "crystal" -Arguments @(
    "build",
    "src/amber_beta_smoke.cr",
    "-o",
    "bin/amber_beta_smoke.exe"
  )

  $server = $null
  $previousServerPort = $env:AMBER_SERVER_PORT
  try {
    $env:AMBER_SERVER_PORT = "3210"
    $serverPath = Join-Path $appPath "bin/amber_beta_smoke.exe"
    $serverLog = Join-Path $appPath "server.log"
    $serverErrorLog = Join-Path $appPath "server-error.log"
    $server = Start-Process `
      -FilePath $serverPath `
      -PassThru `
      -RedirectStandardOutput $serverLog `
      -RedirectStandardError $serverErrorLog

    $homepage = $null
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
      try {
        $homepage = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:3210/"
        break
      } catch {
        Start-Sleep -Seconds 1
      }
    }
    if (-not $homepage) {
      $serverOutput = if (Test-Path $serverErrorLog) { [System.IO.File]::ReadAllText($serverErrorLog) } else { "" }
      throw "Generated Windows app did not serve its homepage. $serverOutput"
    }
    foreach ($expected in @("Your new idea", $css.path, $javascript.path, $logo.path, $favicon.path, 'integrity="sha256-')) {
      if (-not $homepage.Content.Contains($expected)) {
        throw "Generated homepage did not contain expected asset/page content: $expected"
      }
    }

    $cssResponse = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:3210$($css.path)"
    if (-not $cssResponse.Content.Contains("--amber-accent: #e96918") -or -not $cssResponse.Content.Contains($logo.path)) {
      throw "Fingerprint CSS response did not contain the starter style and rewritten image URL"
    }
    if ($cssResponse.Headers["Content-Type"] -notmatch "text/css") {
      throw "Fingerprint CSS response has the wrong MIME type"
    }
    if ($cssResponse.Headers["Cache-Control"] -notmatch "max-age=31536000" -or $cssResponse.Headers["Cache-Control"] -notmatch "immutable") {
      throw "Fingerprint CSS response is missing immutable caching"
    }

    $javascriptResponse = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:3210$($javascript.path)"
    if ($javascriptResponse.Content -notmatch 'dataset\.javascript = "ready"' -or $javascriptResponse.Headers["Content-Type"] -notmatch "javascript") {
      throw "Fingerprint JavaScript response has the wrong body or MIME type"
    }

    $logoResponse = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:3210$($logo.path)"
    if ($logoResponse.Content -notmatch "<svg" -or $logoResponse.Headers["Content-Type"] -notmatch "image/svg\+xml") {
      throw "Fingerprint SVG response has the wrong body or MIME type"
    }

    $gzipHeadersPath = Join-Path $appPath "gzip-headers.txt"
    $gzipBodyPath = Join-Path $appPath "gzip-body.bin"
    & curl.exe --fail --silent `
      --header "Accept-Encoding: gzip" `
      --dump-header $gzipHeadersPath `
      --output $gzipBodyPath `
      "http://127.0.0.1:3210$($css.path)"
    if ($LASTEXITCODE -ne 0) {
      throw "Windows gzip asset request failed with exit code $LASTEXITCODE"
    }
    $gzipHeaders = [System.IO.File]::ReadAllText($gzipHeadersPath)
    if ($gzipHeaders -notmatch "(?im)^Content-Encoding:\s*gzip" -or
        $gzipHeaders -notmatch "(?im)^Content-Type:\s*text/css" -or
        $gzipHeaders -notmatch "(?im)^Vary:\s*Accept-Encoding") {
      throw "Windows gzip asset response is missing encoding, CSS MIME, or Vary headers"
    }
  } finally {
    $env:AMBER_SERVER_PORT = $previousServerPort
    if ($server -and -not $server.HasExited) {
      Stop-Process -Id $server.Id -Force
      Wait-Process -Id $server.Id -ErrorAction SilentlyContinue
    }
  }
} finally {
  Pop-Location
}
