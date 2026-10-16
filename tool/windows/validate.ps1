[CmdletBinding()]
param(
    [string]$Flutter = 'flutter',
    [switch]$Integration
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $IsWindows) { throw 'Windows validation requires PowerShell 7 on Windows.' }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    function Invoke-Flutter {
        & $Flutter @args
        if ($LASTEXITCODE -ne 0) { throw "Flutter command failed: $args" }
    }
    $pin = (Get-Content .fvmrc -Raw | ConvertFrom-Json).flutter
    # Bootstrap a fresh SDK before parsing its machine-readable version.
    Invoke-Flutter --version
    $machineVersion = & $Flutter --version --machine
    if ($LASTEXITCODE -ne 0) { throw "Flutter version command failed: $machineVersion" }
    $version = ($machineVersion | ConvertFrom-Json).frameworkVersion
    if ($LASTEXITCODE -ne 0 -or $version -ne $pin) {
        throw "Expected Flutter $pin from .fvmrc; found $version."
    }
    $flutterPath = (Get-Command $Flutter).Source
    $dart = Join-Path (Split-Path $flutterPath) 'dart.bat'
    if (-not (Test-Path $dart)) { throw 'Dart must sit beside Flutter.' }
    $env:PATH = "$(Split-Path $flutterPath);$env:PATH"
    Invoke-Flutter config --enable-windows-desktop
    Invoke-Flutter pub get --enforce-lockfile
    & $dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool/motion_probe.dart
    if ($LASTEXITCODE -ne 0) { throw 'Dart formatting check failed.' }
    Invoke-Flutter analyze
    & $dart run rive_native:setup --verbose --platform windows
    if ($LASTEXITCODE -ne 0) { throw 'Rive Windows native runtime setup failed.' }
    Invoke-Flutter test
    & cmake -S windows/native_tests -B build/windows-native-tests
    if ($LASTEXITCODE -ne 0) { throw 'Native test CMake configuration failed.' }
    & cmake --build build/windows-native-tests --config Release
    if ($LASTEXITCODE -ne 0) { throw 'Native test build failed.' }
    & ctest --test-dir build/windows-native-tests -C Release --output-on-failure
    if ($LASTEXITCODE -ne 0) { throw 'Native boundary tests failed.' }
    if ($Integration) {
        # Requires an interactive local Windows desktop; hosted CI keeps this off.
        Invoke-Flutter test integration_test/windows_wifi_test.dart -d windows
    }
    # Build normal entry point after integration tests, before packaging.
    Invoke-Flutter build windows --release
    & (Join-Path $PSScriptRoot 'package.ps1')
} finally {
    Pop-Location
}
