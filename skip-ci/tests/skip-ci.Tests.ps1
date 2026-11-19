BeforeAll {
    $runsPath = 'repos/getsentry/repo/actions/workflows/ci.yml/runs?head_sha=before&event=pull_request&status=success'
    $comparePath = 'repos/getsentry/repo/compare/before...head'

    function Invoke-SkipCi
    {
        $output = New-TemporaryFile
        $summary = New-TemporaryFile
        $env:GITHUB_OUTPUT = $output
        $env:GITHUB_STEP_SUMMARY = $summary
        try
        {
            $log = & "$PSScriptRoot/../scripts/skip-ci.ps1" *>&1 | Out-String
            [pscustomobject]@{
                Log      = $log
                Output   = (Get-Content $output -Raw).Trim()
                Summary  = Get-Content $summary -Raw
                ExitCode = $LASTEXITCODE
            }
        }
        finally
        {
            Remove-Item $output, $summary
        }
    }

    # Runs the script and fails the test if it hit an unexpected error.
    function Invoke-SkipCiChecked
    {
        $result = Invoke-SkipCi
        $result.Log | Should -Not -Match '::warning::'
        $result
    }
}

Describe 'skip-ci' {
    BeforeEach {
        $env:EVENT_NAME = 'pull_request'
        $env:EVENT_ACTION = 'synchronize'
        $env:BEFORE = 'before'
        $env:HEAD = 'head'
        $env:HEAD_REF = 'feat/x'
        $env:HEAD_REPOSITORY = 'getsentry/repo'
        $env:PR_NUMBER = '1'
        $env:REPOSITORY = 'getsentry/repo'
        $env:WORKFLOW_REF = 'getsentry/repo/.github/workflows/ci.yml@refs/pull/1/merge'
        $env:PATHS = "**/*.md`n!package/**"

        $runs = @{ workflow_runs = @(@{
                    head_branch     = 'feat/x'
                    head_repository = @{ full_name = 'getsentry/repo' }
                    pull_requests   = @(@{ number = 1 })
                }) }
        $compare = @{ status = 'ahead'; files = @(@{ filename = 'CHANGELOG.md' }, @{ filename = 'docs/a.md' }) }

        Mock gh { $global:LASTEXITCODE = 0; $runs | ConvertTo-Json -Depth 10 } -ParameterFilter { $args[1] -eq $runsPath }
        Mock gh { $global:LASTEXITCODE = 0; $compare | ConvertTo-Json -Depth 10 } -ParameterFilter { $args[1] -eq $comparePath }
    }

    It 'skips when only matching files changed since a passing head' {
        $result = Invoke-SkipCiChecked
        $result.Output | Should -Be 'skip=true'
        $result.Summary | Should -Match 'before'
        $result.ExitCode | Should -Be 0
        Should -Invoke gh -Times 1 -Exactly -ParameterFilter { $args[1] -eq $runsPath }
        Should -Invoke gh -Times 1 -Exactly -ParameterFilter { $args[1] -eq $comparePath }
    }

    It 'skips when the passing run is for a fork, which lists no pull requests' {
        $env:HEAD_REPOSITORY = 'someone/repo'
        $runs.workflow_runs = @(@{ head_branch = 'feat/x'; head_repository = @{ full_name = 'someone/repo' }; pull_requests = @() })
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=true'
    }

    It 'runs when a file does not match' {
        $compare.files += @{ filename = 'src/a.cs' }
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
    }

    It 'runs when a code file was renamed to a matching name' {
        $compare.files = @(@{ filename = 'a.md'; previous_filename = 'a.cs' })
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
    }

    It 'runs when an excluded file changed' {
        $compare.files = @(@{ filename = 'package/README.md' })
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
    }

    It 'runs when the previous head has no successful run' {
        $runs.workflow_runs = @()
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
        Should -Invoke gh -Times 0 -ParameterFilter { $args[1] -eq $comparePath }
    }

    It 'runs when the only successful run is for another <Case>' -TestCases @(
        @{ Case = 'branch'; Branch = 'other'; Repository = 'getsentry/repo'; Number = 1 },
        @{ Case = 'fork'; Branch = 'feat/x'; Repository = 'someone/repo'; Number = 1 },
        @{ Case = 'pull request'; Branch = 'feat/x'; Repository = 'getsentry/repo'; Number = 2 }) {
        $runs.workflow_runs = @(@{
                head_branch     = $Branch
                head_repository = @{ full_name = $Repository }
                pull_requests   = @(@{ number = $Number })
            })
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
    }

    It 'runs when the new head is <Status>' -TestCases @(
        @{ Status = 'diverged' }, @{ Status = 'behind' }, @{ Status = 'identical' }) {
        $compare.status = $Status
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
    }

    It 'runs when <Count> files are listed' -TestCases @(@{ Count = 0 }, @{ Count = 300 }) {
        $compare.files = @(1..$Count | Where-Object { $Count -gt 0 } | ForEach-Object { @{ filename = "$_.md" } })
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
    }

    It 'runs for <Name> <Action>' -TestCases @(
        @{ Name = 'push'; Action = '' },
        @{ Name = 'pull_request'; Action = 'opened' },
        @{ Name = 'pull_request_target'; Action = 'synchronize' }) {
        $env:EVENT_NAME = $Name
        $env:EVENT_ACTION = $Action
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
        Should -Invoke gh -Times 0
    }

    It 'runs and exits 0 when the API fails' {
        Mock gh { $global:LASTEXITCODE = 1; Write-Error 'HTTP 404: Not Found' -ErrorAction Continue } -ParameterFilter { $args[1] -eq $comparePath }
        $result = Invoke-SkipCi
        $result.Output | Should -Be 'skip=false'
        $result.ExitCode | Should -Be 0
        $result.Log | Should -Match '::warning::'
    }
}
