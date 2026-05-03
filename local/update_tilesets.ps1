<#
.SYNOPSIS
    Downloads and installs the latest tileset releases into the gfx directory.

.DESCRIPTION
    Queries the latest release from each repository listed in $Repos via the
    GitHub CLI (gh). Compares the release tag against a locally stored version
    file to skip repos that are already up to date. New releases are downloaded
    as .zip archives to a temporary directory, extracted in parallel into
    $Destination, and the version file is updated on success. Any tileset names
    listed in $SkipTilesets are excluded from extraction.

.REQUIREMENTS
    - PowerShell 7+
    - GitHub CLI (gh) authenticated with sufficient read access

.NOTES
    Version files are stored as hidden dotfiles in $Destination, named after
    the repo slug (e.g. .I-am-Erk_CDDA-Tilesets.version).
    Tilesets are installed to the userdata gfx directory so they survive rebuilds.
#>
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $MyInvocation.MyCommand.Path) + $MyInvocation.BoundParameters.GetEnumerator().ForEach({ "-$($_.Key)", $_.Value })
    & pwsh.exe @argList
    exit $LASTEXITCODE
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$Destination = Join-Path $env:USERPROFILE "cdda\userdata\gfx"
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "cdda_tilesets"
$Repos = @(
    "I-am-Erk/CDDA-Tilesets"
)
$SkipTilesets = @(
    "Larwick_Overmap"
)

function Get-InstalledVersion {
    param([string]$Repository)

    $repoSlug = $Repository -replace "/", "_"
    $versionFile = Join-Path $Destination ".${repoSlug}.version"
    if (Test-Path $versionFile) {
        return Get-Content $versionFile -Raw
    }
    return $null
}

function Set-InstalledVersion {
    param([string]$Repository, [string]$TagName)

    $repoSlug = $Repository -replace "/", "_"
    $versionFile = Join-Path $Destination ".${repoSlug}.version"
    Set-Content $versionFile $TagName
}

function Get-PendingUpdate {
    param([string]$Repository)

    Write-Host "Fetching latest release metadata from $Repository via GitHub CLI"
    $tagName = (gh release list --repo $Repository --limit 1 --json tagName | ConvertFrom-Json)[0].tagName
    Write-Host "Latest release: $tagName"

    $installedVersion = Get-InstalledVersion -Repository $Repository
    if ($installedVersion -and $installedVersion.Trim() -eq $tagName) {
        Write-Host "$Repository is already up to date ($tagName). Skipping."
        return $null
    }

    return $tagName
}

# MAIN EXECUTION
foreach ($Repo in $Repos) {
    $tagName = Get-PendingUpdate -Repository $Repo
    if (-not $tagName) { continue }

    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    try {
        Write-Host "Downloading all tilesets from $Repo $tagName..."
        gh release download $tagName --repo $Repo --pattern "*.zip" --dir $TempDir --clobber

        Get-ChildItem $TempDir -Filter "*.zip" | Where-Object { $_.BaseName -notin $SkipTilesets } | ForEach-Object -Parallel {
            Write-Host "Extracting $($_.Name)..."
            [System.IO.Compression.ZipFile]::ExtractToDirectory($_.FullName, $using:Destination, $true)
        }

        Set-InstalledVersion -Repository $Repo -TagName $tagName
        Write-Host "All tileset archives downloaded and extracted successfully."
    }
    finally {
        Remove-Item -Path $TempDir -Recurse -Force
    }
}
