<#
.SYNOPSIS
    Syncs the fork's master branch from upstream and rebases the current branch onto it.

.DESCRIPTION
    Runs the following steps in order:
      1. Fetch latest commits from upstream into local upstream/master
      2. Force-push upstream/master to origin/master
      3. Rebase the current branch onto upstream/master (auto-stashing uncommitted changes)
      4. Push the current branch to origin

    Exits immediately if any step fails. If the rebase has conflicts,
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

Write-Host "`n=== Rebasing $CurrentBranch onto upstream/master ===" -ForegroundColor Cyan
Invoke-Git "rebase", "--autostash", "upstream/master"

Write-Host "`n=== Pushing $CurrentBranch to origin ===" -ForegroundColor Cyan
Invoke-Git "push", "origin", $CurrentBranch, "--force-with-lease"

Write-Host "`n=== Sync complete ===" -ForegroundColor Green
