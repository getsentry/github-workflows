Set-StrictMode -Version latest

Describe 'nonbot-commits' {
    Context 'Repo <_>' -ForEach @('https://github.com/getsentry/github-workflows', 'git@github.com:getsentry/github-workflows.git') {
        BeforeEach {
            $repoUrl = $_
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
        }

        It 'empty-if-all-commits-by-bot' {
            $commits = NonBotCommits 'deps/updater/tests/sentry-cli.properties'
            $commits | Should -BeNullOrEmpty
        }

        It 'empty-if-branch-doesnt-exist' {
            $commits = NonBotCommits 'non-existent-branch'
            $commits | Should -BeNullOrEmpty
        }

        It 'non-empty-if-changed' {
            $commits = NonBotCommits 'test/nonbot-commits'
            $commits | Should -Be '0b7d9cc test: keep this branch'
        }
    }
}
