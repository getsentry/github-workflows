Set-StrictMode -Version latest

. "$PSScriptRoot/common/test-utils.ps1"

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

RunTest "properties-file" {
    $testFile = "$testDir/test.properties"
    @("repo=$repoUrl", "version  =   none") | Out-File $testFile
    UpdateDependency $testFile
    AssertEqual @("repo=$repoUrl", "version  =   $currentVersion") (Get-Content $testFile)
}

RunTest "version pattern match" {
    $testFile = "$testDir/test.properties"
    $repo = 'https://github.com/getsentry/sentry-cli'
    @("repo=$repo", "version=0") | Out-File $testFile
    UpdateDependency $testFile '^0\.'
    AssertEqual @("repo=$repo", "version=0.28.0") (Get-Content $testFile)
}

function _testOutput([string[]] $output)
{
    AssertContains $output 'originalTag=0'
    AssertContains $output 'originalTag=0'
    AssertContains $output 'latestTag=0.28.0'
    AssertContains $output 'latestTagNice=v0.28.0'
    AssertContains $output 'url=https://github.com/getsentry/sentry-cli'
    AssertContains $output 'mainBranch=master'
}

RunTest "writes output" {
    $testFile = "$testDir/test.properties"
    $repo = 'https://github.com/getsentry/sentry-cli'
    @("repo=$repo", "version=0") | Out-File $testFile
    $stdout = UpdateDependency $testFile '^0\.'
    _testOutput $stdout
}

RunTest "writes to env:GITHUB_OUTPUT" {
    $testFile = "$testDir/test.properties"
    $repo = 'https://github.com/getsentry/sentry-cli'
    @("repo=$repo", "version=0") | Out-File $testFile
    $outFile = "$testDir/outfile"
    New-Item $outFile -ItemType File
    try
    {
        $env:GITHUB_OUTPUT = $outFile
        $stdout = UpdateDependency $testFile '^0\.'
        Write-Host "Testing standard output"
        _testOutput $stdout
        Write-Host "Testing env:GITHUB_OUTPUT"
        _testOutput (Get-Content $outFile)
    }
    finally
    {
        # Delete the file and unser the env variable
        Remove-Item $outFile
        Remove-Item env:GITHUB_OUTPUT
    }
}

# Note: without custom sorting, this would have yielded 'v1.7.31_gradle_plugin'
RunTest "version sorting must work properly" {
    $testFile = "$testDir/test.properties"
    $repo = 'https://github.com/getsentry/sentry-java'
    @("repo=$repo", "version=0") | Out-File $testFile
    UpdateDependency $testFile '^v?[123].*$'
    AssertEqual @("repo=$repo", "version=3.2.1") (Get-Content $testFile)
}

RunTest "powershell-script" {
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
    AssertEqual $currentVersion (Get-Content $testFile)
}

RunTest "bash-script" {
    $testFile = "$testDir/test.version"
    '' | Out-File $testFile
    $testScript = "$testDir/test.sh"
    @'
#!/usr/bin/env bash
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
    AssertEqual $currentVersion (Get-Content $testFile)
} -skipReason ($IsWindows ? "on Windows" : '')

RunTest "powershell-script fails in get-version" {
    $testScript = "$testDir/test.ps1"
    @'
throw "Failure"
'@ | Out-File $testScript

    AssertFailsWith "get-version  | output: Failure" { UpdateDependency $testScript }
}

RunTest "bash-script fails in get-version" {
    $testScript = "$testDir/test.sh"
    @'
#!/usr/bin/env bash
echo "Failure"
exit 1
'@ | Out-File $testScript

    AssertFailsWith "get-version  | output: Failure" { UpdateDependency $testScript }
} -skipReason ($IsWindows ? "on Windows" : '')

RunTest "powershell-script fails in get-repo" {
    $testScript = "$testDir/test.ps1"
    @'
param([string] $action, [string] $value)
if ($action -eq "get-repo")
{
    throw "Failure"
}
'@ | Out-File $testScript

    AssertFailsWith "get-repo  | output: Failure" { UpdateDependency $testScript }
}

RunTest "bash-script fails in get-repo" {
    $testScript = "$testDir/test.sh"
    @'
#!/usr/bin/env bash
case $1 in
get-version)
    ;;
get-repo)
    echo "Failure"
    exit 1
;;
esac
'@ | Out-File $testScript

    AssertFailsWith "get-repo  | output: Failure" { UpdateDependency $testScript }
} -skipReason ($IsWindows ? "on Windows" : '')

RunTest "powershell-script fails in set-version" {
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

    AssertFailsWith "set-version $currentVersion | output: Failure" { UpdateDependency $testScript }
}

RunTest "bash-script fails in set-version" {
    $testScript = "$testDir/test.sh"
    @'
#!/usr/bin/env bash
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

    AssertFailsWith "set-version $currentVersion | output: Failure" { UpdateDependency $testScript }
} -skipReason ($IsWindows ? "on Windows" : '')