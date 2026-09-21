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
