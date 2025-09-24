BeforeAll {
    function UpdateDependency([Parameter(Mandatory = $true)][string] $path, [string] $pattern = $null, [string] $ghTitlePattern = $null)
    {
        $params = @{ Path = $path }
        if ($pattern) { $params.Pattern = $pattern }
        if ($ghTitlePattern) { $params.GhTitlePattern = $ghTitlePattern }

        $result = & "$PSScriptRoot/../scripts/update-dependency.ps1" @params
        if (-not $?)
        {
            throw $result
        }
        $result
    }

    $testDir = "$PSScriptRoot/testdata/dependencies"
    if (-not (Test-Path $testDir))
    {
        New-Item $testDir -ItemType Directory
    }
    $repoUrl = 'https://github.com/getsentry/github-workflows'

    # Find the latest latest version in this repo using the same logic as update-dependency.ps1
    . "$PSScriptRoot/../scripts/common.ps1"
    [string[]]$tags = $(git ls-remote --refs --tags $repoUrl)
    $tags = $tags | ForEach-Object { ($_ -split '\s+')[1] -replace '^refs/tags/', '' }
    $tags = $tags -match '^v?([0-9.]+)$'
    $tags = & "$PSScriptRoot/../scripts/sort-versions.ps1" $tags
    $currentVersion = $tags[-1]
}

Describe ('update-dependency') {
    Context ('properties-file') {
        It 'works' {
            $testFile = "$testDir/test.properties"
            @("repo=$repoUrl", 'version  =   none') | Out-File $testFile
            UpdateDependency $testFile
            Get-Content $testFile | Should -Be @("repo=$repoUrl", "version  =   $currentVersion")
        }

        It 'version pattern match' {
            $testFile = "$testDir/test.properties"
            $repo = 'https://github.com/getsentry/sentry-cli'
            @("repo=$repo", 'version=0') | Out-File $testFile
            UpdateDependency $testFile '^0\.'
            Get-Content $testFile | Should -Be @("repo=$repo", 'version=0.28.0')
        }

        # Note: without custom sorting, this would have yielded 'v1.7.31_gradle_plugin'
        It 'version sorting must work properly' {
            $testFile = "$testDir/test.properties"
            $repo = 'https://github.com/getsentry/sentry-java'
            @("repo=$repo", 'version=0') | Out-File $testFile
            UpdateDependency $testFile '^v?[123].*$'
            Get-Content $testFile | Should -Be @("repo=$repo", 'version=3.2.1')
        }

        It 'will not update from a later release to an earlier release' {
            $testFile = "$testDir/test.properties"
            $repo = 'https://github.com/getsentry/sentry-java'
            @("repo=$repo", 'version=999.0.0-beta.1') | Out-File $testFile
            UpdateDependency $testFile
            Get-Content $testFile | Should -Be @("repo=$repo", 'version=999.0.0-beta.1')
        }
    }

    Context 'bash-script' -Skip:$IsWindows {
        It 'works' {
            $testFile = "$testDir/test.version"
            '' | Out-File $testFile
            $testScript = "$testDir/test.sh"
            @'
#!/usr/bin/env bash
set -euo pipefail
cd $(dirname "$0")
case $1 in
get-version)
    cat test.version
    ;;
get-repo)
    echo
'@ + ' "' + $repoUrl + '"' + @'
    ;;
set-version)
    echo $2 > test.version
    ;;
*)
    echo "Unknown argument $1"
    exit 1
    ;;
esac
'@ | Out-File $testScript
            UpdateDependency $testScript
    (Get-Content $testFile) | Should -Be $currentVersion
        }

        It 'fails in get-version' {
            $testScript = "$testDir/test.sh"
            @'
#!/usr/bin/env bash
echo "Failure"
exit 1
'@ | Out-File $testScript

            { UpdateDependency $testScript } | Should -Throw '*get-version  | output: Failure*'
        }

        It 'fails in get-repo' {
            $testScript = "$testDir/test.sh"
            @'
#!/usr/bin/env bash
set -euo pipefail
case $1 in
get-version)
    ;;
get-repo)
    echo "Failure"
    exit 1
;;
esac
'@ | Out-File $testScript

            { UpdateDependency $testScript } | Should -Throw '*get-repo  | output: Failure*'
        }

        It 'fails in set-version' {
            $testScript = "$testDir/test.sh"
            @'
#!/usr/bin/env bash
set -euo pipefail
cd $(dirname "$0")
case $1 in
get-version)
    echo ""
    ;;
get-repo)
    echo
'@ + ' "' + $repoUrl + '"' + @'
    ;;
set-version)
    echo "Failure"
    exit 1
    ;;
esac
'@ | Out-File $testScript

            { UpdateDependency $testScript } | Should -Throw "*set-version $currentVersion | output: Failure*"
        }
    }

    Context 'powershell-script' {
        It 'works' {
            $testFile = "$testDir/test.version"
            '' | Out-File $testFile
            $testScript = "$testDir/test.ps1"
            @'
param([string] $action, [string] $value)
$file = "$PSScriptRoot/test.version"
switch ($action)
{
    "get-version" { Get-Content $file }
    "get-repo" {
'@ + '"' + $repoUrl + '"' + @'
    }
    "set-version" { $value | Out-File $file }
    Default { throw "Unknown action $action" }
}
'@ | Out-File $testScript
            UpdateDependency $testScript
            Get-Content $testFile | Should -Be $currentVersion
        }

        It 'fails in get-version' {
            $testScript = "$testDir/test.ps1"
            @'
throw "Failure"
'@ | Out-File $testScript

            { UpdateDependency $testScript } | Should -Throw '*get-version  | output: Failure*'
        }

        It 'fails in get-repo' {
            $testScript = "$testDir/test.ps1"
            @'
param([string] $action, [string] $value)
if ($action -eq "get-repo")
{
    throw "Failure"
}
'@ | Out-File $testScript

            { UpdateDependency $testScript } | Should -Throw '*get-repo  | output: Failure*'
        }

        It 'fails in set-version' {
            $testScript = "$testDir/test.ps1"
            @'
param([string] $action, [string] $value)
switch ($action)
{
    "get-version" { '' }
    "get-repo" {
'@ + '"' + $repoUrl + '"' + @'
    }
    "set-version" { throw "Failure" }
}
'@ | Out-File $testScript

            { UpdateDependency $testScript } | Should -Throw "*set-version $currentVersion | output: Failure*"
        }
    }

    Context ('output') {
        BeforeAll {
            function _testOutput([string[]] $output)
            {
                $output | Should -Contain 'originalTag=0'
                $output | Should -Contain 'originalTag=0'
                $output | Should -Contain 'latestTag=0.28.0'
                $output | Should -Contain 'latestTagNice=v0.28.0'
                $output | Should -Contain 'url=https://github.com/getsentry/sentry-cli'
                $output | Should -Contain 'mainBranch=master'
            }
        }

        It 'writes output' {
            $testFile = "$testDir/test.properties"
            $repo = 'https://github.com/getsentry/sentry-cli'
            @("repo=$repo", 'version=0') | Out-File $testFile
            $stdout = UpdateDependency $testFile '^0\.'
            _testOutput $stdout
        }

        It 'writes to env:GITHUB_OUTPUT' {
            $testFile = "$testDir/test.properties"
            $repo = 'https://github.com/getsentry/sentry-cli'
            @("repo=$repo", 'version=0') | Out-File $testFile
            $outFile = "$testDir/outfile"
            New-Item $outFile -ItemType File | Out-Null
            try
            {
                $env:GITHUB_OUTPUT = $outFile
                $stdout = UpdateDependency $testFile '^0\.'
                Write-Host 'Testing standard output'
                _testOutput $stdout
                Write-Host 'Testing env:GITHUB_OUTPUT'
                _testOutput (Get-Content $outFile)
            }
            finally
            {
                # Delete the file and unser the env variable
                Remove-Item $outFile | Out-Null
                Remove-Item env:GITHUB_OUTPUT | Out-Null
            }
        }
    }

    Context 'cmake-fetchcontent' {
        BeforeAll {
            $cmakeTestDir = "$testDir/cmake"
            if (-not (Test-Path $cmakeTestDir)) {
                New-Item $cmakeTestDir -ItemType Directory
            }
        }

        It 'updates CMake file with explicit dependency name' {
            $testFile = "$cmakeTestDir/sentry-explicit.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG v0.9.1
    GIT_SHALLOW FALSE
)

FetchContent_MakeAvailable(sentry-native)
'@ | Out-File $testFile

            UpdateDependency "$testFile#sentry-native"

            $content = Get-Content $testFile -Raw
            $content | Should -Not -Match 'v0.9.1'
            $content | Should -Match 'GIT_TAG \d+\.\d+\.\d+'
            $content | Should -Match 'GIT_REPOSITORY https://github.com/getsentry/sentry-native'
        }

        It 'auto-detects single FetchContent dependency' {
            $testFile = "$cmakeTestDir/sentry-auto.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG v0.9.0
    GIT_SHALLOW FALSE
)

FetchContent_MakeAvailable(sentry-native)
'@ | Out-File $testFile

            UpdateDependency $testFile

            $content = Get-Content $testFile -Raw
            $content | Should -Not -Match 'v0.9.0'
            $content | Should -Match 'GIT_TAG \d+\.\d+\.\d+'
        }

        It 'updates from hash to newer tag preserving hash format' {
            $testFile = "$cmakeTestDir/sentry-hash.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG a64d5bd8ee130f2cda196b6fa7d9b65bfa6d32e2 # 0.9.1
    GIT_SHALLOW FALSE
)

FetchContent_MakeAvailable(sentry-native)
'@ | Out-File $testFile

            UpdateDependency $testFile

            $content = Get-Content $testFile -Raw
            # Should update to a new hash with tag comment
            $content | Should -Match 'GIT_TAG [a-f0-9]{40} # \d+\.\d+\.\d+'
            $content | Should -Not -Match 'a64d5bd8ee130f2cda196b6fa7d9b65bfa6d32e2'
        }

        It 'handles multiple dependencies with explicit selection' {
            $testFile = "$cmakeTestDir/multiple-deps.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG v0.9.1
)

FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest
    GIT_TAG v1.14.0
)

FetchContent_MakeAvailable(sentry-native googletest)
'@ | Out-File $testFile

            UpdateDependency "$testFile#googletest"

            $content = Get-Content $testFile -Raw
            # sentry-native should remain unchanged
            $content | Should -Match 'sentry-native[\s\S]*GIT_TAG v0\.9\.1'
            # googletest should be updated
            $content | Should -Match 'googletest[\s\S]*GIT_TAG v1\.\d+\.\d+'
            $content | Should -Not -Match 'googletest[\s\S]*GIT_TAG v1\.14\.0'
        }

        It 'outputs correct GitHub Actions variables' {
            $testFile = "$cmakeTestDir/output-test.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG v0.9.0
)
'@ | Out-File $testFile

            $output = UpdateDependency $testFile

            # Join output lines for easier searching
            $outputText = $output -join "`n"
            $outputText | Should -Match 'originalTag=v0\.9\.0'
            $outputText | Should -Match 'latestTag=\d+\.\d+\.\d+'
            $outputText | Should -Match 'url=https://github.com/getsentry/sentry-native'
            $outputText | Should -Match 'mainBranch=master'
        }

        It 'respects version patterns' {
            $testFile = "$cmakeTestDir/pattern-test.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG v0.8.0
)
'@ | Out-File $testFile

            # Limit to 0.9.x versions
            UpdateDependency $testFile '^v?0\.9\.'

            $content = Get-Content $testFile -Raw
            $content | Should -Match 'GIT_TAG 0\.9\.\d+'
            $content | Should -Not -Match 'v0\.8\.0'
        }

        It 'fails on multiple dependencies without explicit name' {
            $testFile = "$cmakeTestDir/multi-fail.cmake"
            @'
include(FetchContent)

FetchContent_Declare(sentry-native GIT_REPOSITORY https://github.com/getsentry/sentry-native GIT_TAG v0.9.1)
FetchContent_Declare(googletest GIT_REPOSITORY https://github.com/google/googletest GIT_TAG v1.14.0)
'@ | Out-File $testFile

            { UpdateDependency $testFile } | Should -Throw '*Multiple FetchContent declarations found*'
        }

        It 'fails on missing dependency' {
            $testFile = "$cmakeTestDir/missing-dep.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG v0.9.1
)
'@ | Out-File $testFile

            { UpdateDependency "$testFile#nonexistent" } | Should -Throw "*FetchContent_Declare for 'nonexistent' not found*"
        }
    }

    Context 'gh-title-pattern' {
        It 'filters by GitHub release title pattern' {
            $testFile = "$testDir/test.properties"
            # Use sentry-cocoa repo which has releases with "(Stable)" suffix
            $repo = 'https://github.com/getsentry/sentry-cocoa'
            @("repo=$repo", 'version=0') | Out-File $testFile

            # Test filtering for releases with "(Stable)" suffix
            UpdateDependency $testFile '' '\(Stable\)$'

            $content = Get-Content $testFile
            $version = ($content | Where-Object { $_ -match '^version\s*=\s*(.+)$' }) -replace '^version\s*=\s*', ''

            # Verify that a version was selected (should be a stable release)
            $version | Should -Not -Be '0'
            $version | Should -Match '^\d+\.\d+\.\d+$'
        }

        It 'throws error when no releases match title pattern' {
            $testFile = "$testDir/test.properties"
            # Use a smaller repo that's less likely to timeout
            $repo = 'https://github.com/getsentry/github-workflows'
            @("repo=$repo", 'version=0') | Out-File $testFile

            # Use a pattern that should match no releases
            { UpdateDependency $testFile '' 'NonExistentPattern' } | Should -Throw '*Found no tags with GitHub releases matching title pattern*'
        }

        It 'works without title pattern (backward compatibility)' {
            $testFile = "$testDir/test.properties"
            $repo = 'https://github.com/getsentry/sentry-cocoa'
            @("repo=$repo", 'version=0') | Out-File $testFile

            # Test without title pattern should work as before
            UpdateDependency $testFile '^8\.'

            $content = Get-Content $testFile
            $version = ($content | Where-Object { $_ -match '^version\s*=\s*(.+)$' }) -replace '^version\s*=\s*', ''

            # Should get a version starting with 8
            $version | Should -Match '^8\.'
        }

    }
}
