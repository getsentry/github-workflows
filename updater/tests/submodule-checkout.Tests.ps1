BeforeAll {
    $script:updater = "$PSScriptRoot/../scripts/update-dependency.ps1"
    $script:previousProtocols = $env:GIT_ALLOW_PROTOCOL
    $env:GIT_ALLOW_PROTOCOL = 'file'

    function script:Invoke-FixtureGit {
        git @args
        if ($LASTEXITCODE -ne 0) { throw "Could not create Git fixture: 'git $args' exited with $LASTEXITCODE" }
    }
}

AfterAll { $env:GIT_ALLOW_PROTOCOL = $script:previousProtocols }

Describe 'Submodule initialization' {
    BeforeEach {
        $script:pushedLocation = $false
        $script:caseDir = Join-Path $TestDrive ([guid]::NewGuid())
        $script:remote = "$caseDir/remote"
        Invoke-FixtureGit init --quiet --initial-branch=main $remote
        Invoke-FixtureGit -C $remote config user.name 'Updater tests'
        Invoke-FixtureGit -C $remote config user.email 'updater@example.invalid'
        Invoke-FixtureGit -C $remote -c commit.gpgsign=false commit --quiet --allow-empty -m base
        Invoke-FixtureGit -C $remote tag 1.0.0
        Invoke-FixtureGit -C $remote checkout --quiet -b release
        Invoke-FixtureGit -C $remote -c commit.gpgsign=false commit --quiet --allow-empty -m release
        Invoke-FixtureGit -C $remote tag 1.1.0
        $script:pin = Invoke-FixtureGit -C $remote rev-parse HEAD
        Invoke-FixtureGit -C $remote checkout --quiet main
        Invoke-FixtureGit -C $remote -c commit.gpgsign=false commit --quiet --allow-empty -m development
        Invoke-FixtureGit init --quiet "$caseDir/caller"
        Push-Location "$caseDir/caller"
        $script:pushedLocation = $true
        $remoteUrl = ([uri]::new((Resolve-Path $remote).ProviderPath)).AbsoluteUri
        Invoke-FixtureGit config -f .gitmodules submodule.dependency.path dependency
        Invoke-FixtureGit config -f .gitmodules submodule.dependency.url $remoteUrl
        Invoke-FixtureGit add .gitmodules
        Invoke-FixtureGit update-index --add --cacheinfo "160000,$pin,dependency"
        New-Item dependency -ItemType Directory | Out-Null
    }

    # Popping without a matching push would hide the setup failure behind a stack error.
    AfterEach { if ($script:pushedLocation) { Pop-Location } }

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
