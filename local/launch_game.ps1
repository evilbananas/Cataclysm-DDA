<#
.SYNOPSIS
    Launches the locally-built CDDA executable with a persistent userdata directory.

.DESCRIPTION
    Runs cataclysm-tiles.exe from the repo root, passing --userdir so that all
    saves, config, and mods are stored in a directory that survives rebuilds.
    Creates the userdata directory if it does not already exist.

.NOTES
    Userdata location: $env:USERPROFILE\cdda\userdata
#>
$ErrorActionPreference = "Stop"

$Root       = Resolve-Path (Join-Path $PSScriptRoot "..")
$Exe        = Join-Path $Root "cataclysm-tiles.exe"
$UserData   = Join-Path $env:USERPROFILE "cdda\userdata"
$CacheDirs  = @(
    Join-Path $Root "data\cache"
    Join-Path $UserData "cache"
)

if (-not (Test-Path $Exe)) {
    Write-Error "Executable not found: $Exe`nRun the 'MSBuild: Quick|x64' task first."
    exit 1
}

if (-not (Test-Path $UserData)) {
    Write-Host "Creating userdata directory: $UserData"
    New-Item -ItemType Directory -Path $UserData -Force | Out-Null
}

# Remove stale caches - the game regenerates them on first run
foreach ($CacheDir in $CacheDirs) {
    if (Test-Path $CacheDir) {
        Write-Host "Clearing stale data cache: $CacheDir"
        Remove-Item $CacheDir -Recurse -Force
    }
}

Write-Host "Launching CDDA with --userdir $UserData" -ForegroundColor Cyan
Start-Process -FilePath $Exe -ArgumentList "--userdir", $UserData -WorkingDirectory $Root
