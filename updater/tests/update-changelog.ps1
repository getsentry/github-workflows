Set-StrictMode -Version latest

. "$PSScriptRoot/common/test-utils.ps1"

$testCases = Get-ChildItem "$PSScriptRoot/testdata/changelog/"

foreach ($testCase in $testCases)
{
    RunTest $testCase {
        Copy-Item "$testCase/CHANGELOG.md.original" "$testCase/CHANGELOG.md"

        pwsh -WorkingDirectory $testCase -File "$PSScriptRoot/../scripts/update-changelog.ps1" `
            -Name 'Dependency' `
            -PR 'https://github.com/getsentry/dependant/pulls/123' `
            -RepoUrl 'https://github.com/getsentry/dependency' `
            -MainBranch 'main' `
            -OldTag '7.16.0' `
            -NewTag '7.17.0' `
            -Section 'Dependencies'

        AssertEqual (Get-Content "$testCase/CHANGELOG.md.expected") (Get-Content "$testCase/CHANGELOG.md")
    }
}
