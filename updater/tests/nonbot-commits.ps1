Set-StrictMode -Version latest

. "$PSScriptRoot/common/test-utils.ps1"

function NonBotCommits([Parameter(Mandatory = $true)][string] $branch)
{
    $result = & "$PSScriptRoot/../scripts/nonbot-commits.ps1" `
        -RepoUrl 'https://github.com/getsentry/github-workflows' -MainBranch "main" -PrBranch $branch
    if (-not $?)
    {
        throw $result
    }
    $result
}

RunTest "empty-if-all-commits-by-bot" {
    $commits = NonBotCommits 'deps/updater/tests/sentry-cli.properties'
    AssertEqual "$commits" ""
}

RunTest "empty-if-branch-doesnt-exist" {
    $commits = NonBotCommits 'non-existent-branch'
    AssertEqual "$commits" ""
}

RunTest "non-empty-if-changed" {
    $commits = NonBotCommits 'test/nonbot-commits'
    AssertEqual "$commits" "6133a25 Update README.md"
}
