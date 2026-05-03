<#
.SYNOPSIS
    Launches the locally-built CDDA executable with a persistent userdata directory.

.DESCRIPTION
    Runs cataclysm-tiles.exe from the repo root, passing --userdir so that all
    saves, config, and mods are stored in a directory that survives rebuilds.
    Creates the userdata directory if it does not already exist.

.NOTES
    Userdata location: $env:USERPROFILE\cdda\userdata
    To migrate existing saves from a previous location, run migrate_userdata.ps1 first.
#>
$ErrorActionPreference = "Stop"

$Root     = Resolve-Path (Join-Path $PSScriptRoot "..")
$Exe      = Join-Path $Root "cataclysm-tiles.exe"
$UserData = Join-Path $env:USERPROFILE "cdda\userdata"

if (-not (Test-Path $Exe)) {
    Write-Error "Executable not found: $Exe`nRun the 'MSBuild: Quick|x64' task first."
    exit 1
}

if (-not (Test-Path $UserData)) {
    Write-Host "Creating userdata directory: $UserData"
    New-Item -ItemType Directory -Path $UserData -Force | Out-Null
}

# Remove stale cache - the game regenerates it on first run
$CacheDir = Join-Path $Root "data\cache"
if (Test-Path $CacheDir) {
    Write-Host "Clearing stale data cache..."
    Remove-Item $CacheDir -Recurse -Force
}

Write-Host "Launching CDDA with --userdir $UserData" -ForegroundColor Cyan
Start-Process -FilePath $Exe -ArgumentList "--userdir", $UserData -WorkingDirectory $Root
