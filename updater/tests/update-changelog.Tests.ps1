
Describe 'update-changelog' {
    It '<_>' -ForEach @(Get-ChildItem "$PSScriptRoot/testdata/changelog/") {
        $testCase = $_
        Copy-Item "$testCase/CHANGELOG.md.original" "$testCase/CHANGELOG.md"

        pwsh -WorkingDirectory $testCase -File "$PSScriptRoot/../scripts/update-changelog.ps1" `
            -Name 'Dependency' `
            -PR 'https://github.com/getsentry/dependant/pulls/123' `
            -RepoUrl 'https://github.com/getsentry/dependency' `
            -MainBranch 'main' `
            -OldTag '7.16.0' `
            -NewTag '7.17.0' `
            -Section 'Dependencies'

        Get-Content "$testCase/CHANGELOG.md" | Should -Be (Get-Content "$testCase/CHANGELOG.md.expected")
    }

    It 'should correctly detect bullet points when plain text appears before bullet points' {
        $testCasePath = "$PSScriptRoot/testdata/changelog/plain-text-intro"
        Copy-Item "$testCasePath/CHANGELOG.md.original" "$testCasePath/CHANGELOG.md"

        pwsh -WorkingDirectory $testCasePath -File "$PSScriptRoot/../scripts/update-changelog.ps1" `
            -Name 'Dependency' `
            -PR 'https://github.com/getsentry/dependant/pulls/123' `
            -RepoUrl 'https://github.com/getsentry/dependency' `
            -MainBranch 'main' `
            -OldTag '7.16.0' `
            -NewTag '7.17.0' `
            -Section 'Dependencies'

        #  verify the full output matches expected
        Get-Content "$testCasePath/CHANGELOG.md" | Should -Be (Get-Content "$testCasePath/CHANGELOG.md.expected")
    }

    It 'should handle changelogs with no bullet points by defaulting to dash' {
        $testCasePath = "$PSScriptRoot/testdata/changelog/no-bullet-points"
        Copy-Item "$testCasePath/CHANGELOG.md.original" "$testCasePath/CHANGELOG.md"

        pwsh -WorkingDirectory $testCasePath -File "$PSScriptRoot/../scripts/update-changelog.ps1" `
            -Name 'Dependency' `
            -PR 'https://github.com/getsentry/dependant/pulls/123' `
            -RepoUrl 'https://github.com/getsentry/dependency' `
            -MainBranch 'main' `
            -OldTag '7.16.0' `
            -NewTag '7.17.0' `
            -Section 'Dependencies'

        Get-Content "$testCasePath/CHANGELOG.md" | Should -Be (Get-Content "$testCasePath/CHANGELOG.md.expected")
    }
}
