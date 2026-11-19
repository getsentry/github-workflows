# Decides whether a push to a pull request only changes files that don't need CI.
# Writes `skip=true` to GITHUB_OUTPUT only when all of these hold:
# - the event is `pull_request` with action `synchronize`;
# - the same workflow has a successful run for the previous head that lists this pull request;
# - the new head is strictly ahead of the previous head (no force-push dropped commits);
# - between 1 and 299 files changed, and every file (and the old name of a renamed file) matches `PATHS`.
# Any error leaves `skip=false`, so CI runs. The script always exits 0.

Set-StrictMode -Version latest
$ErrorActionPreference = 'Stop'

function Invoke-GhApi([string] $path)
{
    $json = gh api $path
    if ($LASTEXITCODE -ne 0)
    {
        throw "gh api $path failed with exit code $LASTEXITCODE"
    }
    $json | ConvertFrom-Json
}

function Get-SkipReason
{
    if ($env:EVENT_NAME -ne 'pull_request' -or $env:EVENT_ACTION -ne 'synchronize' -or -not $env:BEFORE)
    {
        Write-Host 'Not a push to an open pull request; CI runs.'
        return $null
    }

    # WORKFLOW_REF looks like 'owner/repo/.github/workflows/ci.yml@refs/pull/1/merge'.
    # The runs API takes the file name; the full path returns 404.
    $workflow = Split-Path -Leaf ($env:WORKFLOW_REF -replace '@.*$', '')

    $runs = Invoke-GhApi "repos/$env:REPOSITORY/actions/workflows/$workflow/runs?head_sha=$env:BEFORE&event=pull_request&status=success"
    # A run lists every open pull request with its head, not only the one it ran for; runs for forks list none.
    $passed = @($runs.workflow_runs | Where-Object {
            $_.head_branch -eq $env:HEAD_REF -and $_.head_repository.full_name -eq $env:HEAD_REPOSITORY -and
            (@($_.pull_requests).Count -eq 0 -or @($_.pull_requests | Where-Object { "$($_.number)" -eq $env:PR_NUMBER }).Count -gt 0)
        })
    if ($passed.Count -eq 0)
    {
        Write-Host "$workflow has no successful run for the previous head $env:BEFORE; CI runs."
        return $null
    }

    # The compare API lists at most 300 files.
    $compare = Invoke-GhApi "repos/$env:REPOSITORY/compare/$env:BEFORE...$env:HEAD"
    $files = @($compare.files)
    if ($compare.status -ne 'ahead' -or $files.Count -eq 0 -or $files.Count -ge 300)
    {
        Write-Host "Comparing $env:BEFORE...$env:HEAD gives status '$($compare.status)' with $($files.Count) files; CI runs."
        return $null
    }

    $names = @(foreach ($file in $files)
        {
            $file.filename
            if ($file.PSObject.Properties['previous_filename'])
            {
                $file.previous_filename
            }
        })
    $patterns = @($env:PATHS -split "`n")
    if (-not (& "$PSScriptRoot/match-paths.ps1" -Files $names -Patterns $patterns))
    {
        Write-Host "Some files changed since $env:BEFORE don't match ``paths``; CI runs."
        return $null
    }

    "Only files matching ``paths`` changed since $env:BEFORE, which passed $workflow."
}

$skip = $false
try
{
    $reason = Get-SkipReason
    if ($reason)
    {
        $skip = $true
        Write-Host $reason
        if ($env:GITHUB_STEP_SUMMARY)
        {
            "$reason Skipping the jobs that depend on it." | Out-File $env:GITHUB_STEP_SUMMARY -Append
        }
    }
}
catch
{
    Write-Host "::warning::Couldn't check the changes, so CI runs: $_"
}

if ($env:GITHUB_OUTPUT)
{
    "skip=$($skip.ToString().ToLower())" | Out-File $env:GITHUB_OUTPUT -Append
}
exit 0
