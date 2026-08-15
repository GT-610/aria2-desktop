param(
  [string]$BuildName = '0.0.0',
  [string]$BuildNumber = '0'
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'aria2_next_release.json') | ConvertFrom-Json
$aria2Version = $manifest.version
$temporaryDirectory = Join-Path $env:TEMP "setsuna-aria2-next-$aria2Version"
$preparedCoreDirectory = Join-Path $temporaryDirectory 'core'
$releaseDirectory = Join-Path $workspace 'build\windows\x64\runner\Release'
$coreDirectory = Join-Path $releaseDirectory 'data\core'

Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
& (Join-Path $PSScriptRoot 'prepare_aria2_next.ps1') -Target 'windows-x64' -Destination $preparedCoreDirectory

Remove-Item -LiteralPath (Join-Path $workspace 'build\windows') -Recurse -Force -ErrorAction SilentlyContinue
Push-Location $workspace
try {
  flutter pub get
  flutter build windows --release --no-pub --build-name=$BuildName --build-number=$BuildNumber
} finally {
  Pop-Location
}

New-Item -ItemType Directory -Force -Path $coreDirectory | Out-Null
foreach ($fileName in @(
  'aria2c.exe',
  'aria2.conf',
  'aria2-next.COPYING',
  'ARIA2_NEXT_NOTICE.txt'
)) {
  Copy-Item -LiteralPath (Join-Path $preparedCoreDirectory $fileName) -Destination $coreDirectory -Force
}
Remove-Item -LiteralPath (Join-Path $coreDirectory 'aria2.log') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $coreDirectory 'aria2.session') -Force -ErrorAction SilentlyContinue

foreach ($requiredFile in @(
  'aria2c.exe',
  'aria2.conf',
  'aria2-next.COPYING',
  'ARIA2_NEXT_NOTICE.txt'
)) {
  if (-not (Test-Path -LiteralPath (Join-Path $coreDirectory $requiredFile))) {
    throw "Release artifact is missing $requiredFile."
  }
}

foreach ($forbiddenFile in @('aria2.log', 'aria2.session')) {
  if (Test-Path -LiteralPath (Join-Path $coreDirectory $forbiddenFile)) {
    throw "Release artifact contains forbidden runtime file: $forbiddenFile"
  }
}

$settingsPath = Join-Path $releaseDirectory 'data\config\settings.json'
if (Test-Path -LiteralPath $settingsPath) {
  throw 'Release artifact contains a local settings file.'
}

Push-Location $workspace
try {
  dart run tool/smoke_test_aria2_next.dart `
    --executable (Join-Path $coreDirectory 'aria2c.exe') `
    --config (Join-Path $coreDirectory 'aria2.conf') `
    --expected-version $aria2Version
} finally {
  Pop-Location
}

Write-Host "Reproducible Windows release with Aria2 Next $aria2Version created at $releaseDirectory"
