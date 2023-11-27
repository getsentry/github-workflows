# Finds commits in a branch that weren't made by <noreply@github.com>
param(
    [Parameter(Mandatory = $true)][string] $RepoUrl,
    [Parameter(Mandatory = $true)][string] $PrBranch,
    [Parameter(Mandatory = $true)][string] $MainBranch
)

Set-StrictMode -Version latest
$ErrorActionPreference = 'Stop'

$RepoUrl = $RepoUrl -replace 'git@github.com:', 'https://github.com/'
$bot = '<noreply@github.com>'

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
New-Item -ItemType Directory $tmpDir | Out-Null
Push-Location $tmpDir
try
{
    Write-Host "Looking for commits on $RepoUrl branch '$PrBranch' that were made by someone else than $bot"

    git init | Out-Null
    git remote add origin $RepoUrl | Out-Host
    git fetch --depth 1 origin $MainBranch | Out-Host
    git fetch --depth 1 origin $PrBranch | Out-Host

    #Note: we're intentionally ignoring exit codes from git, to make sure we don't fail if the branch doesn't exist.
    $allCommits = @(git log --oneline "origin/$MainBranch..origin/$PrBranch")
    $botCommits = @(git log --oneline "origin/$MainBranch..origin/$PrBranch" --author=$bot)
    $nonbotCommits = @(Compare-Object -ReferenceObject $allCommits -DifferenceObject $botCommits -PassThru)

    if ($nonbotCommits.Length -gt 0)
    {
`
            Write-Warning "There are commits made by others than $bot"
    }
    $nonbotCommits
}
finally
{
    Pop-Location
    Write-Host "Removing $tmpDir"
    Remove-Item -Recurse -Force -ErrorAction Continue -Path $tmpDir
}

# Don't propagate error exit code from git commands.
exit 0