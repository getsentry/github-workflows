BeforeAll {
    # Stands in for the gh CLI: answers `gh api <path>` from $global:GhResponses, keyed by path prefix.
    function gh
    {
        $path = $args[1]
        $global:GhCalls += $path
        foreach ($key in $global:GhResponses.Keys)
        {
            if ($path.StartsWith($key))
            {
                $global:LASTEXITCODE = 0
                return ($global:GhResponses[$key] | ConvertTo-Json -Depth 10)
            }
        }
        $global:LASTEXITCODE = 1
        Write-Error "HTTP 404: Not Found ($path)" -ErrorAction Continue
    }

    # Runs the script and fails the test if it hit an unexpected error.
    function Invoke-SkipCiChecked
    {
        $result = Invoke-SkipCi
        $result.Log | Should -Not -Match '::warning::'
        $result
    }

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

    $runsPath = 'repos/getsentry/repo/actions/workflows/ci.yml/runs?head_sha=before&event=pull_request&status=success'
    $comparePath = 'repos/getsentry/repo/compare/before...head'
}

Describe 'skip-ci' {
    AfterAll {
        Remove-Variable GhCalls, GhResponses -Scope Global
    }

    BeforeEach {
        $env:EVENT_NAME = 'pull_request'
        $env:EVENT_ACTION = 'synchronize'
        $env:BEFORE = 'before'
        $env:HEAD = 'head'
        $env:HEAD_REF = 'feat/x'
        $env:HEAD_REPOSITORY = 'getsentry/repo'
        $env:REPOSITORY = 'getsentry/repo'
        $env:WORKFLOW_REF = 'getsentry/repo/.github/workflows/ci.yml@refs/pull/1/merge'
        $env:PATHS = "**/*.md`n!package/**"
        $global:GhCalls = @()
        $global:GhResponses = @{
            $runsPath    = @{ workflow_runs = @(@{ head_branch = 'feat/x'; head_repository = @{ full_name = 'getsentry/repo' } }) }
            $comparePath = @{ status = 'ahead'; files = @(@{ filename = 'CHANGELOG.md' }, @{ filename = 'docs/a.md' }) }
        }
    }

    It 'skips when only matching files changed since a passing head' {
        $result = Invoke-SkipCiChecked
        $result.Output | Should -Be 'skip=true'
        $result.Summary | Should -Match 'before'
        $result.ExitCode | Should -Be 0
        $global:GhCalls | Should -Be @($runsPath, $comparePath)
    }

    It 'runs when a file does not match' {
        $global:GhResponses[$comparePath].files += @{ filename = 'src/a.cs' }
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
    }

    It 'runs when a code file was renamed to a matching name' {
        $global:GhResponses[$comparePath].files = @(@{ filename = 'a.md'; previous_filename = 'a.cs' })
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
    }

    It 'runs when an excluded file changed' {
        $global:GhResponses[$comparePath].files = @(@{ filename = 'package/README.md' })
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
    }

    It 'runs when the previous head has no successful run' {
        $global:GhResponses[$runsPath].workflow_runs = @()
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
        $global:GhCalls | Should -Be @($runsPath)
    }

    It 'runs when the only successful run is for another branch or fork' {
        $global:GhResponses[$runsPath].workflow_runs = @(
            @{ head_branch = 'other'; head_repository = @{ full_name = 'getsentry/repo' } },
            @{ head_branch = 'feat/x'; head_repository = @{ full_name = 'someone/repo' } })
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
    }

    It 'runs when the new head is not strictly ahead' -TestCases @(
        @{ Status = 'diverged' }, @{ Status = 'behind' }, @{ Status = 'identical' }) {
        $global:GhResponses[$comparePath].status = $Status
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
    }

    It 'runs when no files or 300 files are listed' {
        $global:GhResponses[$comparePath].files = @()
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
        $global:GhResponses[$comparePath].files = @(1..300 | ForEach-Object { @{ filename = "$_.md" } })
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
    }

    It 'runs for other events and actions' -TestCases @(
        @{ Name = 'push'; Action = '' },
        @{ Name = 'pull_request'; Action = 'opened' },
        @{ Name = 'pull_request_target'; Action = 'synchronize' }) {
        $env:EVENT_NAME = $Name
        $env:EVENT_ACTION = $Action
        (Invoke-SkipCiChecked).Output | Should -Be 'skip=false'
        $global:GhCalls | Should -BeNullOrEmpty
    }

    It 'runs and exits 0 when the API fails' {
        $global:GhResponses.Remove($comparePath)
        $result = Invoke-SkipCi
        $result.Output | Should -Be 'skip=false'
        $result.ExitCode | Should -Be 0
        $result.Log | Should -Match '::warning::'
    }
}
