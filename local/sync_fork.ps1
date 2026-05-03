<#
.SYNOPSIS
    Syncs the fork's master branch from upstream and merges it into the current branch.

.DESCRIPTION
    Runs the following steps in order:
      1. Fetch latest commits from upstream (CleverRaven/Cataclysm-DDA)
      2. Stash any uncommitted local changes
      3. Fast-forward local master to upstream/master
      4. Push updated master to origin (your fork on GitHub)
      5. Return to the previous branch
      6. Restore stashed changes
      7. Merge master into the current branch

    Exits immediately if any step fails. If the merge has conflicts,
    it will stop and let you resolve them manually.

.REQUIREMENTS
    - Git with upstream remote pointing to CleverRaven/Cataclysm-DDA
#>
$ErrorActionPreference = "Stop"

function Invoke-Git {
    param([string[]]$Args)
    & git @Args
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git $($Args -join ' ') failed (exit $LASTEXITCODE)."
        exit $LASTEXITCODE
    }
}

$CurrentBranch = (git rev-parse --abbrev-ref HEAD).Trim()

Write-Host "=== Fetching upstream ===" -ForegroundColor Cyan
Invoke-Git "fetch", "upstream"

Write-Host "`n=== Stashing local changes ===" -ForegroundColor Cyan
$StashOutput = git stash 2>&1
$Stashed = $StashOutput -notcontains "No local changes to save"
Write-Host $StashOutput

Write-Host "`n=== Updating master ===" -ForegroundColor Cyan
Invoke-Git "checkout", "master"
Invoke-Git "merge", "--ff-only", "upstream/master"

Write-Host "`n=== Pushing master to origin ===" -ForegroundColor Cyan
Invoke-Git "push", "origin", "master"

Write-Host "`n=== Returning to $CurrentBranch ===" -ForegroundColor Cyan
Invoke-Git "checkout", $CurrentBranch

if ($Stashed) {
    Write-Host "`n=== Restoring stash ===" -ForegroundColor Cyan
    Invoke-Git "stash", "pop"
}

Write-Host "`n=== Merging master into $CurrentBranch ===" -ForegroundColor Cyan
Invoke-Git "merge", "master"

Write-Host "`n=== Sync complete ===" -ForegroundColor Green
