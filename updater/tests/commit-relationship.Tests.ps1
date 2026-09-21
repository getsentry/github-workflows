BeforeAll {
    $script:updater = "$PSScriptRoot/../scripts/update-dependency.ps1"
    $script:remote = "$TestDrive/remote"
    git init --quiet --initial-branch=main $remote
    git -C $remote config user.name 'Updater tests'
    git -C $remote config user.email 'updater@example.invalid'
    git -C $remote -c commit.gpgsign=false commit --quiet --allow-empty -m base
    git -C $remote tag 1.0.0
    git -C $remote -c commit.gpgsign=false commit --quiet --allow-empty -m behind
    $script:behind = git -C $remote rev-parse HEAD
    git -C $remote -c commit.gpgsign=false commit --quiet --allow-empty -m release
    $script:release = git -C $remote rev-parse HEAD
    git -C $remote -c tag.gpgsign=false tag -a 1.1.0 -m release
    git -C $remote tag 1.1.1
    git -C $remote -c commit.gpgsign=false commit --quiet --allow-empty -m ahead
    $script:ahead = git -C $remote rev-parse HEAD
    git -C $remote checkout --quiet --detach 1.0.0
    git -C $remote -c commit.gpgsign=false commit --quiet --allow-empty -m divergent
    $script:divergent = git -C $remote rev-parse HEAD
    git -C $remote branch divergent
    git -C $remote checkout --quiet main
    if ($LASTEXITCODE -ne 0) { throw 'Could not create Git fixture' }
}

Describe 'Automatic updates of Git revisions' {
    BeforeEach {
        $script:caseDir = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item $caseDir -ItemType Directory | Out-Null
        Push-Location $caseDir
    }

    AfterEach { Pop-Location }

    It '<kind>: <state> pin against <target>' -ForEach @(
        foreach ($kind in @('CMake', 'submodule')) {
            foreach ($state in @('behind', 'release', 'ahead', 'divergent')) {
                foreach ($target in @('1.1.0', '1.1.1')) {
                    @{ kind = $kind; state = $state; target = $target }
                }
            }
        }
    ) {
        $pin = Get-Variable $state -ValueOnly
        if ($kind -eq 'CMake') {
            $path = "$caseDir/dependency.cmake"
            @"
FetchContent_Declare(
    dependency
    GIT_REPOSITORY $remote
    GIT_TAG $pin
)
"@ | Set-Content $path
            $original = Get-Content $path -Raw
        } else {
            git init --quiet
            git -c protocol.file.allow=always submodule add --quiet $remote dependency
            git -C dependency checkout --quiet $pin
            git add dependency
            $path = 'dependency'
        }
        $params = @{ Path = $path; Pattern = '^' + [regex]::Escape($target) + '$' }
        if ($state -eq 'divergent') {
            { & $updater @params } | Should -Throw '*diverg*'
        } else {
            $output = & $updater @params -WarningVariable warnings
            $LASTEXITCODE | Should -Be 0
            $warnings | Should -BeNullOrEmpty
            if ($state -eq 'behind') {
                $output | Should -Contain "latestTag=$target"
            } else {
                $originalTag = ($output | Where-Object { $_ -like 'originalTag=*' }) -replace '^originalTag=', ''
                $output | Should -Contain "latestTag=$originalTag"
            }
        }
        $expected = if ($state -eq 'behind') { $release } else { $pin }
        if ($kind -eq 'CMake') {
            if ($state -eq 'behind') {
                Get-Content $path -Raw | Should -Match "GIT_TAG $expected # $target"
            } else {
                Get-Content $path -Raw | Should -BeExactly $original
            }
        } else {
            git -C $path rev-parse HEAD | Should -Be $expected
        }
    }
}

Describe 'Ancestry lookup failures' {
    BeforeAll { . "$PSScriptRoot/../scripts/cmake-functions.ps1" }

    It 'reports an unavailable commit as an error' {
        { Test-HashAncestry $remote ('f' * 40) $release } | Should -Throw '*fetch*'
    }
}

Describe 'Commit comparison errors' {
    BeforeAll {
        . "$PSScriptRoot/../scripts/git-functions.ps1"
        $script:gitExecutable = (Get-Command git -CommandType Application | Select-Object -First 1).Source
    }

    It 'rejects an invalid <revision> revision' -ForEach @(
        @{ revision = 'current' }
        @{ revision = 'target' }
    ) {
        $current = if ($revision -eq 'current') { 'missing' } else { $behind }
        $target = if ($revision -eq 'target') { 'missing' } else { $release }
        { Get-CommitRelationship $remote $current $target } | Should -Throw "*resolve $revision revision*"
    }

    It 'reports failure of the <direction> ancestry check' -ForEach @(
        @{ direction = 'forward' }
        @{ direction = 'reverse' }
    ) {
        Mock git { & $gitExecutable @args }
        Mock git { $global:LASTEXITCODE = 128 } -ParameterFilter {
            $args -contains 'merge-base' -and ($direction -eq 'forward' -or $args[4] -eq $release)
        }
        { Get-CommitRelationship $remote $ahead $release } | Should -Throw '*merge-base exit code 128*'
    }

    It 'reports an unavailable target separately from divergent history' {
        { Get-RemoteCommitRelationship $remote $behind 'refs/tags/missing' } | Should -Throw '*fetch target revision*'
    }
}

Describe 'Temporary ancestry repository lifecycle' {
    BeforeAll {
        . "$PSScriptRoot/../scripts/git-functions.ps1"
        $script:gitExecutable = (Get-Command git -CommandType Application | Select-Object -First 1).Source
    }

    BeforeEach {
        $script:ancestryRepository = $null
        $script:allowCleanup = $false
        Mock git {
            if ($args -contains 'init') { $script:ancestryRepository = $args[-1] }
            & $gitExecutable @args
        }
    }

    AfterEach {
        # Cleanup-failure tests deliberately leave the repository behind.
        $script:allowCleanup = $true
        if ($ancestryRepository -and (Test-Path $ancestryRepository)) {
            Microsoft.PowerShell.Management\Remove-Item $ancestryRepository -Recurse -Force
        }
    }

    It 'fetches both revisions without launching maintenance in the disposable repository' {
        $tracePath = Join-Path $TestDrive 'git-trace.json'
        $previousTrace = $env:GIT_TRACE2_EVENT
        try {
            $env:GIT_TRACE2_EVENT = $tracePath
            Mock git {
                if ($args -contains 'init') { $script:ancestryRepository = $args[-1] }
                # Force packing after two fetches if maintenance is allowed. Run it
                # in the foreground so the regression test cannot itself race cleanup.
                & $gitExecutable -c maintenance.auto=true -c gc.autoDetach=false `
                    -c maintenance.autoDetach=false -c gc.autoPackLimit=1 -c fetch.unpackLimit=0 @args
            }
            Get-RemoteCommitRelationship $remote $behind $release | Should -Be 'Behind'
            Test-Path $ancestryRepository | Should -BeFalse
        } finally {
            $env:GIT_TRACE2_EVENT = $previousTrace
        }

        $events = Get-Content $tracePath | ForEach-Object { $_ | ConvertFrom-Json }
        @($events | Where-Object { $_.event -eq 'start' -and $_.argv -contains 'fetch' }).Count | Should -Be 2
        @($events | Where-Object { $_.event -eq 'child_start' -and $_.argv -contains 'maintenance' }).Count | Should -Be 0
    }

    It 'reports cleanup failure after a successful comparison' {
        Mock Remove-Item { throw [System.IO.IOException]::new('Simulated cleanup failure') } -ParameterFilter { -not $script:allowCleanup }
        { Get-RemoteCommitRelationship $remote $behind $release } | Should -Throw '*Simulated cleanup failure*'
    }

    It 'preserves a fetch error when cleanup also fails' {
        Mock Remove-Item { throw [System.IO.IOException]::new('Simulated cleanup failure') } -ParameterFilter { -not $script:allowCleanup }
        { Get-RemoteCommitRelationship $remote $behind 'refs/tags/missing' -WarningVariable script:warnings } |
            Should -Throw '*fetch target revision*'
        $warnings | Should -HaveCount 1
        "$warnings" | Should -BeLike "*Could not remove temporary ancestry repository '$ancestryRepository'*Simulated cleanup failure*"
    }

    It 'preserves a comparison error when cleanup also fails' {
        Mock Remove-Item { throw [System.IO.IOException]::new('Simulated cleanup failure') } -ParameterFilter { -not $script:allowCleanup }
        Mock Get-CommitRelationship { throw 'Simulated comparison failure' }
        { Get-RemoteCommitRelationship $remote $behind $release -WarningVariable script:warnings } |
            Should -Throw '*Simulated comparison failure*'
        $warnings | Should -HaveCount 1
        "$warnings" | Should -BeLike "*Could not remove temporary ancestry repository '$ancestryRepository'*Simulated cleanup failure*"
    }
}
