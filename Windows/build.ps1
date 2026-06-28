param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    [switch]$Clean,
    [switch]$Verify
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$WindowsRoot = $PSScriptRoot
$DistRoot = Join-Path $Root "dist\windows"
$BuildRoot = Join-Path $WindowsRoot "build\$Configuration"
$ExePath = Join-Path $BuildRoot "CodexResetWatcher.Windows.exe"
$Csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (!(Test-Path -LiteralPath $Csc)) {
    throw "Could not find the .NET Framework C# compiler at $Csc"
}

if ($Clean) {
    Get-Process -Name "CodexResetWatcher.Windows" -ErrorAction SilentlyContinue | Stop-Process -Force
    Remove-Item -LiteralPath $BuildRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $DistRoot -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null
New-Item -ItemType Directory -Force -Path $DistRoot | Out-Null

$Sources = Get-ChildItem -LiteralPath (Join-Path $WindowsRoot "src") -Filter *.cs | Sort-Object Name | ForEach-Object { $_.FullName }
$References = @(
    "System.dll",
    "System.Core.dll",
    "System.Data.dll",
    "System.Drawing.dll",
    "System.Web.Extensions.dll",
    "System.Windows.Forms.dll",
    "System.Security.dll"
)

$Defines = if ($Configuration -eq "Debug") { "/define:DEBUG;TRACE" } else { "/define:TRACE" }
$Optimize = if ($Configuration -eq "Debug") { "/optimize-" } else { "/optimize+" }

& $Csc /nologo /target:winexe /platform:x64 $Defines $Optimize "/out:$ExePath" ($References | ForEach-Object { "/reference:$_" }) $Sources
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$DistApp = Join-Path $DistRoot "Codex Reset Watcher Windows"
New-Item -ItemType Directory -Force -Path $DistApp | Out-Null
Copy-Item -LiteralPath $ExePath -Destination (Join-Path $DistApp "CodexResetWatcher.Windows.exe") -Force
New-Item -ItemType Directory -Force -Path (Join-Path $DistApp "Assets") | Out-Null
Copy-Item -LiteralPath (Join-Path $Root "Assets\AppIcon.png") -Destination (Join-Path $DistApp "Assets\AppIcon.png") -Force
Copy-Item -LiteralPath (Join-Path $Root "Assets\UsageHeader.png") -Destination (Join-Path $DistApp "Assets\UsageHeader.png") -Force

if ($Verify) {
    $SelfTest = Join-Path $DistRoot "self-test.json"
    & (Join-Path $DistApp "CodexResetWatcher.Windows.exe") --self-test-output $SelfTest
    if ($LASTEXITCODE -ne 0) {
        throw "Windows self-test failed. See $SelfTest"
    }

    $Process = Start-Process -FilePath (Join-Path $DistApp "CodexResetWatcher.Windows.exe") -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 3
    $Running = $null -ne (Get-Process -Id $Process.Id -ErrorAction SilentlyContinue)
    if ($Running) {
        Stop-Process -Id $Process.Id -Force
    } else {
        throw "Windows launch smoke test failed; process exited before verification completed."
    }
}

Write-Host "Built $DistApp"
