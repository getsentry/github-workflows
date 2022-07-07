Set-StrictMode -Version latest

. "$PSScriptRoot/common/test-utils.ps1"

function UpdateDependency([Parameter(Mandatory = $true)][string] $path, [string] $pattern = $null)
{
    $result = & "$PSScriptRoot/../scripts/update-dependency.ps1" -Path $path -Pattern $pattern
    if (-not $?)
    {
        throw $result
    }
}

$testDir = "$PSScriptRoot/testdata/dependencies"
if (-not (Test-Path $testDir))
{
    New-Item $testDir -ItemType Directory
}

$repoUrl = 'https://github.com/getsentry/github-workflows'
$currentVersion = 'v1' # Note: this will change once there's a new tag in this repo

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
}

RunTest "script fails in get-version" {
    $testScript = "$testDir/test.sh"
    @'
#!/usr/bin/env bash
echo "Failure"
exit 1
'@ | Out-File $testScript

    AssertFailsWith "get-version  | output: Failure" { UpdateDependency $testScript }
}

RunTest "script fails in get-repo" {
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
}

RunTest "script fails in set-version" {
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
    echo "Failure"
    exit 1
    ;;
esac
'@ | Out-File $testScript

    AssertFailsWith "set-version $currentVersion | output: Failure" { UpdateDependency $testScript }
}