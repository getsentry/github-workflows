BeforeAll {
    $script:updater = "$PSScriptRoot/../scripts/update-dependency.ps1"
    $script:previousProtocols = $env:GIT_ALLOW_PROTOCOL
    $env:GIT_ALLOW_PROTOCOL = 'file'
}

AfterAll { $env:GIT_ALLOW_PROTOCOL = $script:previousProtocols }

Describe 'Submodule initialization' {
    BeforeEach {
        $script:caseDir = Join-Path $TestDrive ([guid]::NewGuid())
        $script:remote = "$caseDir/remote"
        git init --quiet --initial-branch=main $remote
        git -C $remote config user.name 'Updater tests'
        git -C $remote config user.email 'updater@example.invalid'
        git -C $remote -c commit.gpgsign=false commit --quiet --allow-empty -m base
        git -C $remote tag 1.0.0
        git -C $remote checkout --quiet -b release
        git -C $remote -c commit.gpgsign=false commit --quiet --allow-empty -m release
        git -C $remote tag 1.1.0
        $script:pin = git -C $remote rev-parse HEAD
        git -C $remote checkout --quiet main
        git -C $remote -c commit.gpgsign=false commit --quiet --allow-empty -m development
        git init --quiet "$caseDir/caller"
        Push-Location "$caseDir/caller"
        $remoteUrl = ([uri]::new((Resolve-Path $remote).ProviderPath)).AbsoluteUri
        git config -f .gitmodules submodule.dependency.path dependency
        git config -f .gitmodules submodule.dependency.url $remoteUrl
        git add .gitmodules
        git update-index --add --cacheinfo "160000,$pin,dependency"
        New-Item dependency -ItemType Directory | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not create Git fixture' }
    }

    AfterEach { Pop-Location }

    It 'recognizes an already pinned release outside the default branch' {
        $output = & $updater -Path dependency
        $output | Should -Contain 'originalTag=1.1.0'
        $output | Should -Contain 'latestTag=1.1.0'
        git -C dependency rev-parse HEAD | Should -Be $pin
        git diff --exit-code -- dependency
        $LASTEXITCODE | Should -Be 0
    }

    It 'stops when the pinned commit cannot be checked out' {
        git update-index --cacheinfo '160000,1111111111111111111111111111111111111111,dependency'
        { & $updater -Path dependency } | Should -Throw '*Failed to initialize submodule*'
    }

    It 'stops when fetching tags fails' {
        git submodule update --init --single-branch dependency
        $LASTEXITCODE | Should -Be 0
        git -C dependency remote set-url origin "$caseDir/missing"
        { & $updater -Path dependency } | Should -Throw '*Failed to fetch tags*'
    }
}
