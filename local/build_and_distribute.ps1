<#
.SYNOPSIS
    Builds the project, downloads the latest tilesets and soundpacks, then
    runs the distribute step.

.DESCRIPTION
    Runs the following steps in order:
      1. MSBuild with the Quick|x64 configuration
      2. Download latest tilesets (download_latest_tilesets.ps1)
      3. Download latest soundpacks (download_latest_soundpacks.ps1)
      4. Clean the distribution folder to remove stale files
      5. Run distribute.bat to assemble the distribution folder

    Exits immediately if any step fails.

.REQUIREMENTS
    - PowerShell 7+
    - Visual Studio with MSBuild
    - GitHub CLI (gh) authenticated with sufficient read access
#>
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$SolutionPath = Join-Path $Root "msvc-full-features\Cataclysm-vcpkg-static.sln"

# Step 1: Build
Write-Host "=== Building Quick|x64 ===" -ForegroundColor Cyan
& "$Root\.vscode\msbuild.ps1" -SolutionPath $SolutionPath -Configuration Quick
if ($LASTEXITCODE -ne 0) { Write-Error "Build failed (exit $LASTEXITCODE)."; exit $LASTEXITCODE }

# Step 2: Tilesets
Write-Host "`n=== Downloading latest tilesets ===" -ForegroundColor Cyan
& "$PSScriptRoot\download_latest_tilesets.ps1"
if ($LASTEXITCODE -ne 0) { Write-Error "Tileset download failed (exit $LASTEXITCODE)."; exit $LASTEXITCODE }

# Step 3: Soundpacks
Write-Host "`n=== Downloading latest soundpacks ===" -ForegroundColor Cyan
& "$PSScriptRoot\download_latest_soundpacks.ps1"
if ($LASTEXITCODE -ne 0) { Write-Error "Soundpack download failed (exit $LASTEXITCODE)."; exit $LASTEXITCODE }

# Step 4: Distribute
Write-Host "`n=== Distributing ===" -ForegroundColor Cyan
$distributionDir = Join-Path $Root "msvc-full-features\distribution"
if (Test-Path $distributionDir) {
    Write-Host "Cleaning stale distribution folder..."
    Remove-Item $distributionDir -Recurse -Force
}
$distributeInput = (("A`n") * 10)
$distributeInput | cmd /d /c "cd /d `"$Root\msvc-full-features`" && distribute.bat"
if ($LASTEXITCODE -ne 0) { Write-Error "Distribute failed (exit $LASTEXITCODE)."; exit $LASTEXITCODE }

# Remove stale cache data copied from data/cache - the game regenerates this on first run
$cacheDir = Join-Path $distributionDir "data\cache"
if (Test-Path $cacheDir) {
    Write-Host "Removing stale cache from distribution..."
    Remove-Item $cacheDir -Recurse -Force
}

Write-Host "`n=== Done ===" -ForegroundColor Green
