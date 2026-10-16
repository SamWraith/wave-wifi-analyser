[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$release = Join-Path $projectRoot 'build/windows/x64/runner/Release'
# Ship the complete Flutter bundle, including plugin DLLs and data/flutter_assets.
foreach ($required in @('wifi_analyser.exe', 'flutter_windows.dll', 'rive_native.dll', 'data/flutter_assets')) {
    if (-not (Test-Path (Join-Path $release $required))) {
        throw "Release bundle missing $required. Build successfully before packaging."
    }
}
$dist = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$archive = Join-Path $dist 'wave-wifi-analyser-windows-x64.zip'
Compress-Archive -Path (Join-Path $release '*') -DestinationPath $archive -Force
Get-FileHash $archive -Algorithm SHA256 | Format-List
Write-Output "Complete Windows bundle: $archive"
