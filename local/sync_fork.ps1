<#
.SYNOPSIS
    Syncs the fork's master branch from upstream and merges it into the current branch.

.DESCRIPTION
    Runs the following steps in order:
      1. Sync origin/master with upstream via GitHub CLI (no branch switch needed)
      2. Fetch the updated master locally
      3. Stash any uncommitted local changes
      4. Merge origin/master into the current branch
      5. Restore stashed changes

    Exits immediately if any step fails. If the merge has conflicts,
    it will stop and let you resolve them manually.

.REQUIREMENTS
    - GitHub CLI (gh) authenticated
#>
$ErrorActionPreference = "Stop"

function Invoke-Git {
    param([string[]]$GitArgs)
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git $($GitArgs -join ' ') failed (exit $LASTEXITCODE)."
        exit $LASTEXITCODE
    }
}

function Invoke-Gh {
    param([string[]]$GhArgs)
    & gh @GhArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "gh $($GhArgs -join ' ') failed (exit $LASTEXITCODE)."
        exit $LASTEXITCODE
    }
}

$CurrentBranch = (git rev-parse --abbrev-ref HEAD).Trim()

Write-Host "=== Syncing origin/master with upstream (via gh) ===" -ForegroundColor Cyan
Invoke-Gh "repo", "sync", "--branch", "master"

Write-Host "`n=== Fetching updated master locally ===" -ForegroundColor Cyan
Invoke-Git "fetch", "origin", "master"

Write-Host "`n=== Stashing local changes ===" -ForegroundColor Cyan
$StashOutput = git stash 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "git stash failed (exit $LASTEXITCODE)."
    exit $LASTEXITCODE
}
$Stashed = $StashOutput -notcontains "No local changes to save"
Write-Host $StashOutput

Write-Host "`n=== Merging origin/master into $CurrentBranch ===" -ForegroundColor Cyan
Invoke-Git "merge", "origin/master"

if ($Stashed) {
    Write-Host "`n=== Restoring stash ===" -ForegroundColor Cyan
    Invoke-Git "stash", "pop"
}

Write-Host "`n=== Sync complete ===" -ForegroundColor Green
