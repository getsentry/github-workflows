Set-StrictMode -Version latest

. "$PSScriptRoot/common/test-utils.ps1"

$updateScript = "$PSScriptRoot/../scripts/update-dependency.ps1"
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
    & $updateScript -Path $testFile
    AssertEqual @("repo=$repoUrl", "version  =   $currentVersion") (Get-Content $testFile)
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
    & $updateScript -Path $testScript
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
    & $updateScript -Path $testScript
    AssertEqual $currentVersion (Get-Content $testFile)
}