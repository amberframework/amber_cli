param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Cli
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

Invoke-Checked $cliPath new $appPath --type web --no-deps

Push-Location $appPath
try {
  Invoke-Checked shards install
  Invoke-Checked crystal spec
  New-Item -ItemType Directory -Force bin | Out-Null
  Invoke-Checked crystal build src/amber_beta_smoke.cr -o bin/amber_beta_smoke.exe
} finally {
  Pop-Location
}
