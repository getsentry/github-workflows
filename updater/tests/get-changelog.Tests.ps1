
Describe 'get-changelog' {
    It 'with existing versions' {
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/getsentry/github-workflows' -OldTag '1.0.0' -NewTag '2.1.0'
        $expected = @'
## Changelog
### 2.1.0

#### Features

- New reusable workflow, `danger.yml`, to check Pull Requests with predefined rules ([#34](https://github-redirect.dependabot.com/getsentry/github-workflows/pull/34))

### 2.0.0

#### Changes

- Rename `api_token` secret to `api-token` ([#21](https://github-redirect.dependabot.com/getsentry/github-workflows/pull/21))
- Change changelog target section header from "Features" to "Dependencies" ([#19](https://github-redirect.dependabot.com/getsentry/github-workflows/pull/19))

#### Features

- Add `pr-strategy` switch to choose between creating new PRs or updating an existing one ([#22](https://github-redirect.dependabot.com/getsentry/github-workflows/pull/22))
- Add `changelog-section` input setting to specify target changelog section header ([#19](https://github-redirect.dependabot.com/getsentry/github-workflows/pull/19))

#### Fixes

- Preserve changelog bullet-point format ([#20](https://github-redirect.dependabot.com/getsentry/github-workflows/pull/20))
- Changelog section parsing when an entry text contains the section name in the text ([#25](https://github-redirect.dependabot.com/getsentry/github-workflows/pull/25))
'@

        $actual | Should -Be $expected
    }

    It 'with missing versions' {
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/getsentry/sentry-javascript' -OldTag 'XXXXXXX' -NewTag 'YYYYYYYYY'
        $actual | Should -BeNullOrEmpty
    }

    It 'with missing repo' {
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/getsentry/foo-bar' -OldTag 'XXXXXXX' -NewTag 'YYYYYYYYY'
        # May print a warning but still returns (an empty string)
        $actual | Should -BeNullOrEmpty
    }

    It 'with unsupported repo' {
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://dart.googlesource.com/args' -OldTag 'XXXXXXX' -NewTag 'YYYYYYYYY'
        # May print a warning but still returns (an empty string)
        $actual | Should -BeNullOrEmpty
    }

    It 'removes at-mentions' {
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/getsentry/sentry-cli' -OldTag '2.1.0' -NewTag '2.2.0'
        $expected = @'
## Changelog
### 2.2.0

#### Various fixes & improvements

- feat: Compute and upload il2cpp line mappings ([#1248](https://github-redirect.dependabot.com/getsentry/sentry-cli/issues/1248)) by loewenheim
- ref: Skip protected zip files when uploading debug files ([#1245](https://github-redirect.dependabot.com/getsentry/sentry-cli/issues/1245)) by kamilogorek
'@

        $actual | Should -Be $expected
    }

    It "get-changelog removes doesn't duplicate PR links" {
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/getsentry/sentry-native' -OldTag '0.4.16' -NewTag '0.4.17'
        $expected = @'
## Changelog
### 0.4.17

**Fixes**:

- sentry-native now successfully builds when examples aren't included. ([#702](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/702))

**Thank you**:

Features, fixes and improvements in this release have been contributed by:

- [AenBleidd](https://github-redirect.dependabot.com/AenBleidd)
'@

        $actual | Should -Be $expected
    }

    It 'truncates too long text' {
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/getsentry/sentry-cli' -OldTag '1.0.0' -NewTag '2.4.0'
        if ($actual.Length -gt 61000)
        {
            throw "Expected the content to be truncated to less-than 61k characters, but got: $($actual.Length)"
        }
        $msg = "Changelog content truncated by [0-9]+ characters because it was over the limit \(60000\) and wouldn't fit into PR description."
        if ("$actual" -notmatch $msg)
        {
            Write-Host $actual
            throw "Expected changelog to contain message '$msg'"
        }
    }
}
