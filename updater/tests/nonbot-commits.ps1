Set-StrictMode -Version latest

. "$PSScriptRoot/common/test-utils.ps1"

foreach ($repoUrl in @('https://github.com/getsentry/github-workflows', 'git@github.com:getsentry/github-workflows.git'))
{
    function NonBotCommits([Parameter(Mandatory = $true)][string] $branch)
    {
        $result = & "$PSScriptRoot/../scripts/nonbot-commits.ps1" -RepoUrl $repoUrl -MainBranch 'main' -PrBranch $branch
        if (-not $?)
        {
            throw $result
        }
        elseif ($LASTEXITCODE -ne 0)
        {
            throw "Script finished with exit code $LASTEXITCODE"
        }
        $result
    }

    RunTest 'empty-if-all-commits-by-bot' {
        $commits = NonBotCommits 'deps/updater/tests/sentry-cli.properties'
        AssertEqual '' "$commits"
    }

    RunTest 'empty-if-branch-doesnt-exist' {
        $commits = NonBotCommits 'non-existent-branch'
        AssertEqual '' "$commits"
    }

    RunTest 'non-empty-if-changed' {
        $commits = NonBotCommits 'test/nonbot-commits'
        AssertEqual '0b7d9cc test: keep this branch' "$commits"
    }
}