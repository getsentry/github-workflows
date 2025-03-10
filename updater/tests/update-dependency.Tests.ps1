BeforeAll {
    function UpdateDependency([Parameter(Mandatory = $true)][string] $path, [string] $pattern = $null)
    {
        $result = & "$PSScriptRoot/../scripts/update-dependency.ps1" -Path $path -Pattern $pattern
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

    # Find the latest latest version in this repo. We're intentionally using different code than `update-dependency.ps1`
    # script uses to be able to catch issues, if any.
    $currentVersion = (git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' $repoUrl `
        | Select-Object -Last 1 | Select-String -Pattern 'refs/tags/(.*)$').Matches.Groups[1].Value
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
}
