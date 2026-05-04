<#
.SYNOPSIS
    Syncs the fork's master branch from upstream and merges it into the current branch.

.DESCRIPTION
    Runs the following steps in order:
      1. Fetch latest commits from upstream into local upstream/master
      2. Force-push upstream/master to origin/master
      3. Stash any uncommitted local changes
      4. Merge upstream/master into the current branch
      5. Restore stashed changes
      6. Push the current branch to origin

    Exits immediately if any step fails. If the merge has conflicts,
    it will stop and let you resolve them manually.

.REQUIREMENTS
    - Git with upstream remote pointing to CleverRaven/Cataclysm-DDA
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

$CurrentBranch = (git rev-parse --abbrev-ref HEAD).Trim()

Write-Host "=== Fetching upstream ===" -ForegroundColor Cyan
Invoke-Git "fetch", "upstream"

Write-Host "`n=== Pushing upstream/master to origin/master ===" -ForegroundColor Cyan
Invoke-Git "push", "origin", "upstream/master:master", "--force"

Write-Host "`n=== Stashing local changes ===" -ForegroundColor Cyan
$StashOutput = git stash 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "git stash failed (exit $LASTEXITCODE)."
    exit $LASTEXITCODE
}
$Stashed = $StashOutput -notcontains "No local changes to save"
Write-Host $StashOutput

Write-Host "`n=== Merging upstream/master into $CurrentBranch ===" -ForegroundColor Cyan
Invoke-Git "merge", "upstream/master"

if ($Stashed) {
    Write-Host "`n=== Restoring stash ===" -ForegroundColor Cyan
    Invoke-Git "stash", "pop"
}

Write-Host "`n=== Pushing $CurrentBranch to origin ===" -ForegroundColor Cyan
Invoke-Git "push", "origin", $CurrentBranch

Write-Host "`n=== Sync complete ===" -ForegroundColor Green
