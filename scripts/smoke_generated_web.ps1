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

if ($FrameworkCommit) {
  $shardPath = Join-Path $appPath "shard.yml"
  $manifest = [System.IO.File]::ReadAllText($shardPath)
  $releasedFramework = "    version: 2.0.0-beta.2"
  if (-not $manifest.Contains($releasedFramework)) {
    throw "Generated shard.yml does not contain the expected Amber beta pin"
  }
  $manifest = $manifest.Replace(
    $releasedFramework,
    "    commit: $FrameworkCommit"
  )
  [System.IO.File]::WriteAllText($shardPath, $manifest)
}

Push-Location $appPath
try {
  Invoke-Checked -Command "shards" -Arguments @("install")
  Invoke-Checked -Command "crystal" -Arguments @("spec")
  New-Item -ItemType Directory -Force bin | Out-Null
  Invoke-Checked -Command "crystal" -Arguments @(
    "build",
    "src/amber_beta_smoke.cr",
    "-o",
    "bin/amber_beta_smoke.exe"
  )
} finally {
  Pop-Location
}
