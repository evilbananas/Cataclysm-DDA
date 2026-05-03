<#
.SYNOPSIS
    Downloads and installs the latest soundpack releases into the sound directory.

.DESCRIPTION
    Queries the latest release from each repository listed in $Repos,
    $SourceArchiveRepos, and $RootSourceArchiveRepos via the GitHub CLI (gh).
    Compares the release tag against a locally stored version file to skip
    repos that are already up to date.

    Repos in $Repos publish dedicated asset .zip files per soundpack; these are
    downloaded in parallel and extracted directly into $Destination.

    Repos in $SourceArchiveRepos only publish source archives; the GitHub wrapper
    directory is stripped and the inner soundpack folders are moved into
    $Destination individually.

    Repos in $RootSourceArchiveRepos also use source archives, but the repo root
    itself is the soundpack. The wrapper directory is renamed to the configured
    target name and moved directly into $Destination.

    Any soundpack names listed in $SkipSoundpacks are excluded from extraction.

.REQUIREMENTS
    - PowerShell 7+
    - GitHub CLI (gh) authenticated with sufficient read access

.NOTES
    Version files are stored as hidden dotfiles in $Destination, named after
    the repo slug (e.g. .Fris0uman_CDDA-Soundpacks.version). The $Destination
    directory is created automatically if it does not exist.
    Soundpacks are installed to the userdata sound directory so they survive rebuilds.
#>
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $MyInvocation.MyCommand.Path) + $MyInvocation.BoundParameters.GetEnumerator().ForEach({ "-$($_.Key)", $_.Value })
    & pwsh.exe @argList
    exit $LASTEXITCODE
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$Destination = Join-Path $env:USERPROFILE "cdda\userdata\sound"
$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "cdda_soundpacks"
$Repos = @(
    "Fris0uman/CDDA-Soundpacks"
)
# Repos that only publish source archives (no asset zips). The soundpack
# folder(s) are extracted from the wrapper directory GitHub adds to source zips.
$SourceArchiveRepos = @(
    "Kenan2000/Otopack-Mods-Updates"
)
# Repos where the source archive root IS the soundpack (no inner subfolder).
# Maps repo -> target folder name in $Destination.
$RootSourceArchiveRepos = @{
    "damalsk/damalsksoundpack" = "@'s soundpack"
}
$SkipSoundpacks = @(
    "CO.AG-music-only",
    "CC-Sounds-sfx-only"
)

function Get-VersionFilePath {
    param([string]$Repository)
    $repoSlug = $Repository -replace "/", "_"
    return Join-Path $Destination ".${repoSlug}.version"
}

function Get-InstalledVersion {
    param([string]$Repository)
    $versionFile = Get-VersionFilePath $Repository
    if (Test-Path $versionFile) {
        return Get-Content $versionFile -Raw
    }
    return $null
}

function Set-InstalledVersion {
    param([string]$Repository, [string]$TagName)
    Set-Content (Get-VersionFilePath $Repository) $TagName
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

function Install-AssetZipRepo {
    param([string]$Repository, [string]$TagName)

    Write-Host "Downloading all soundpacks from $Repository $TagName..."
    gh release download $TagName --repo $Repository --pattern "*.zip" --dir $TempDir --clobber

    Get-ChildItem $TempDir -Filter "*.zip" | Where-Object { $_.BaseName -notin $SkipSoundpacks } | ForEach-Object -Parallel {
        Write-Host "Extracting $($_.Name)..."
        [System.IO.Compression.ZipFile]::ExtractToDirectory($_.FullName, $using:Destination, $true)
    }
}

# Downloads a source archive and returns the GitHub wrapper directory path.
function Get-SourceArchiveWrapperDir {
    param([string]$Repository, [string]$TagName)

    Write-Host "Downloading source archive from $Repository $TagName..."
    $archivePath = Join-Path $TempDir "source.zip"
    gh release download $TagName --repo $Repository --archive zip --output $archivePath
    $stagingDir = Join-Path $TempDir "staging"
    [System.IO.Compression.ZipFile]::ExtractToDirectory($archivePath, $stagingDir)
    return Get-ChildItem $stagingDir -Directory | Select-Object -First 1
}

# Repo contains multiple soundpack folders inside the source archive wrapper.
function Install-SourceArchiveRepo {
    param([string]$Repository, [string]$TagName)

    $wrapperDir = Get-SourceArchiveWrapperDir -Repository $Repository -TagName $TagName
    Get-ChildItem $wrapperDir.FullName -Directory | ForEach-Object {
        Write-Host "Installing $($_.Name)..."
        $dest = Join-Path $Destination $_.Name
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Move-Item $_.FullName $dest
    }
}

# Repo root IS the soundpack; wrapper dir is renamed to $TargetName.
function Install-RootSourceArchiveRepo {
    param([string]$Repository, [string]$TagName, [string]$TargetName)

    $wrapperDir = Get-SourceArchiveWrapperDir -Repository $Repository -TagName $TagName
    Write-Host "Installing $TargetName..."
    $dest = Join-Path $Destination $TargetName
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Move-Item $wrapperDir.FullName $dest
}

# MAIN EXECUTION
New-Item -ItemType Directory -Path $Destination -Force | Out-Null

foreach ($Repo in ($Repos + $SourceArchiveRepos + $RootSourceArchiveRepos.Keys)) {
    $tagName = Get-PendingUpdate -Repository $Repo
    if (-not $tagName) { continue }

    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    try {
        if ($Repo -in $SourceArchiveRepos) {
            Install-SourceArchiveRepo -Repository $Repo -TagName $tagName
        } elseif ($RootSourceArchiveRepos.ContainsKey($Repo)) {
            Install-RootSourceArchiveRepo -Repository $Repo -TagName $tagName -TargetName $RootSourceArchiveRepos[$Repo]
        } else {
            Install-AssetZipRepo -Repository $Repo -TagName $tagName
        }

        Set-InstalledVersion -Repository $Repo -TagName $tagName
        Write-Host "$Repo downloaded and installed successfully."
    }
    finally {
        Remove-Item -Path $TempDir -Recurse -Force
    }
}
