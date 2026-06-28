param(
    [string]$Version = "0.3.3-windows.1",
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    [switch]$Verify
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$DistRoot = Join-Path $Root "dist\windows"

& (Join-Path $PSScriptRoot "build.ps1") -Configuration $Configuration -Clean -Verify:$Verify

$AppDir = Join-Path $DistRoot "Codex Reset Watcher Windows"
$GenericZip = Join-Path $DistRoot "Codex.Reset.Watcher.Windows.zip"
$VersionedZip = Join-Path $DistRoot ("Codex.Reset.Watcher.Windows.v{0}.zip" -f $Version)

Remove-Item -LiteralPath $GenericZip -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $VersionedZip -Force -ErrorAction SilentlyContinue
Compress-Archive -LiteralPath $AppDir -DestinationPath $GenericZip -Force
Copy-Item -LiteralPath $GenericZip -Destination $VersionedZip -Force

Write-Host "Packaged $GenericZip"
Write-Host "Packaged $VersionedZip"
