param(
  [Parameter(Mandatory = $true)]
  [string]$Target,

  [Parameter(Mandatory = $true)]
  [string]$Destination
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $PSScriptRoot 'aria2_next_release.json'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$asset = $manifest.assets.PSObject.Properties[$Target].Value

if (-not $asset) {
  throw "Unsupported Aria2 Next target: $Target"
}

$destinationDirectory = New-Item -ItemType Directory -Force -Path $Destination
$downloadPath = Join-Path $destinationDirectory.FullName $asset.file
$repository = $manifest.repository
$version = $manifest.version
$assetUrl = "https://github.com/$repository/releases/download/v$version/$($asset.file)"

Invoke-WebRequest -Uri $assetUrl -OutFile $downloadPath
$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $downloadPath).Hash
if ($actualHash -ne $asset.sha256) {
  throw "Aria2 Next checksum mismatch. Expected $($asset.sha256), got $actualHash."
}

$executableName = if ($Target.StartsWith('windows-')) { 'aria2c.exe' } else { 'aria2c' }
$executablePath = Join-Path $destinationDirectory.FullName $executableName
Move-Item -LiteralPath $downloadPath -Destination $executablePath -Force

$licensePath = Join-Path $destinationDirectory.FullName 'aria2-next.COPYING'
Invoke-WebRequest -Uri $manifest.license.url -OutFile $licensePath
$actualLicenseHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $licensePath).Hash
if ($actualLicenseHash -ne $manifest.license.sha256) {
  throw "Aria2 Next license checksum mismatch. Expected $($manifest.license.sha256), got $actualLicenseHash."
}

Copy-Item -LiteralPath (Join-Path $workspace 'assets\core\aria2.conf') -Destination $destinationDirectory.FullName -Force
Copy-Item -LiteralPath (Join-Path $workspace 'assets\core\ARIA2_NEXT_NOTICE.txt') -Destination $destinationDirectory.FullName -Force

Write-Host "Prepared Aria2 Next $version for $Target at $($destinationDirectory.FullName)"
