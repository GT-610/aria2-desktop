param(
  [string]$BuildName = '0.0.0',
  [string]$BuildNumber = '0'
)

$ErrorActionPreference = 'Stop'
$aria2Version = '1.37.0'
$aria2Sha256 = '67D015301EEF0B612191212D564C5BB0A14B5B9C4796B76454276A4D28D9B288'
$workspace = Split-Path -Parent $PSScriptRoot
$temporaryDirectory = Join-Path $env:TEMP "setsuna-aria2-$aria2Version"
$archive = Join-Path $temporaryDirectory 'aria2.zip'
$expanded = Join-Path $temporaryDirectory 'expanded'
$releaseDirectory = Join-Path $workspace 'build\windows\x64\runner\Release'
$coreDirectory = Join-Path $releaseDirectory 'data\core'

Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
$assetUrl = "https://github.com/aria2/aria2/releases/download/release-$aria2Version/aria2-$aria2Version-win-64bit-build1.zip"
Invoke-WebRequest -Uri $assetUrl -OutFile $archive
$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash
if ($actualHash -ne $aria2Sha256) {
  throw "aria2 checksum mismatch. Expected $aria2Sha256, got $actualHash."
}

Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force
$aria2Executable = Get-ChildItem -Path $expanded -Recurse -Filter aria2c.exe | Select-Object -First 1
if (-not $aria2Executable) {
  throw 'aria2c.exe was not found in the verified archive.'
}

Remove-Item -LiteralPath (Join-Path $workspace 'build\windows') -Recurse -Force -ErrorAction SilentlyContinue
Push-Location $workspace
try {
  flutter pub get
  flutter build windows --release --build-name=$BuildName --build-number=$BuildNumber
} finally {
  Pop-Location
}

New-Item -ItemType Directory -Force -Path $coreDirectory | Out-Null
Copy-Item -LiteralPath $aria2Executable.FullName -Destination (Join-Path $coreDirectory 'aria2c.exe') -Force
Copy-Item -LiteralPath (Join-Path $workspace 'assets\core\aria2.conf') -Destination (Join-Path $coreDirectory 'aria2.conf') -Force
Remove-Item -LiteralPath (Join-Path $coreDirectory 'aria2.log') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $coreDirectory 'aria2.session') -Force -ErrorAction SilentlyContinue

Write-Host "Reproducible Windows release created at $releaseDirectory"
