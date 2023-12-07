. "$PSScriptRoot/common/test-utils.ps1"

RunTest "get-changelog with existing versions" {
    $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
        -RepoUrl "https://github.com/getsentry/sentry-javascript" -OldTag "7.4.0" -NewTag "7.5.1"
    $expected = @'
## Changelog
### 7.5.1

This release removes the `user_id` and the `transaction` field from the dynamic sampling context data that is attached to outgoing requests as well as sent to Relay.

- ref(tracing): Remove transaction name and user_id from DSC ([#5363](https://github-redirect.dependabot.com/getsentry/sentry-javascript/issues/5363))

### 7.5.0

This release adds the `sendDefaultPii` flag to the `Sentry.init` options.
When using performance monitoring capabilities of the SDK, it controls whether user IDs (set via `Sentry.setUser`) are propagated in the `baggage` header of outgoing HTTP requests.
This flag is set to `false` per default, and acts as an opt-in mechanism for sending potentially sensitive data.
If you want to attach user IDs to Sentry transactions and traces, set this flag to `true` but keep in mind that this is potentially sensitive information.

- feat(sdk): Add sendDefaultPii option to the JS SDKs ([#5341](https://github-redirect.dependabot.com/getsentry/sentry-javascript/issues/5341))
- fix(remix): Sourcemaps upload script is missing in the tarball ([#5356](https://github-redirect.dependabot.com/getsentry/sentry-javascript/issues/5356))
- fix(remix): Use cjs for main entry point ([#5352](https://github-redirect.dependabot.com/getsentry/sentry-javascript/issues/5352))
- ref(tracing): Only add `user_id` to DSC if `sendDefaultPii` is `true` ([#5344](https://github-redirect.dependabot.com/getsentry/sentry-javascript/issues/5344))

Work in this release contributed by jkcorrea and nfelger. Thank you for your contributions!

### 7.4.1

This release includes the first _published_ version of `sentry/remix`.

- build(remix): Make remix package public ([#5349](https://github-redirect.dependabot.com/getsentry/sentry-javascript/issues/5349))
'@

    AssertEqual $expected $actual
}

RunTest "get-changelog with missing versions" {
    $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
        -RepoUrl "https://github.com/getsentry/sentry-javascript" -OldTag "XXXXXXX" -NewTag "YYYYYYYYY"
    AssertEqual '' $actual
}

RunTest "get-changelog with missing repo" {
    $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
        -RepoUrl "https://github.com/getsentry/foo-bar" -OldTag "XXXXXXX" -NewTag "YYYYYYYYY"
    # May print a warning but still returns (an empty string)
    AssertEqual '' $actual
}

RunTest "get-changelog with unsupported repo" {
    $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
        -RepoUrl "https://dart.googlesource.com/args" -OldTag "XXXXXXX" -NewTag "YYYYYYYYY"
    # May print a warning but still returns (an empty string)
    AssertEqual '' $actual
}

RunTest "get-changelog removes at-mentions" {
    $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
        -RepoUrl "https://github.com/getsentry/sentry-cli" -OldTag "2.1.0" -NewTag "2.2.0"
    $expected = @'
## Changelog
### 2.2.0

#### Various fixes & improvements

- feat: Compute and upload il2cpp line mappings ([#1248](https://github-redirect.dependabot.com/getsentry/sentry-cli/issues/1248)) by loewenheim
- ref: Skip protected zip files when uploading debug files ([#1245](https://github-redirect.dependabot.com/getsentry/sentry-cli/issues/1245)) by kamilogorek
'@

    AssertEqual $expected $actual
}

RunTest "get-changelog removes doesn't duplicate PR links" {
    $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
        -RepoUrl "https://github.com/getsentry/sentry-native" -OldTag "0.4.16" -NewTag "0.4.17"
    $expected = @'
## Changelog
### 0.4.17

**Fixes**:

- sentry-native now successfully builds when examples aren't included. ([#702](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/702))

**Thank you**:

Features, fixes and improvements in this release have been contributed by:

- [AenBleidd](https://github-redirect.dependabot.com/AenBleidd)
'@

    AssertEqual $expected $actual
}

RunTest "get-changelog truncates too long text" {
    $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
        -RepoUrl "https://github.com/getsentry/sentry-cli" -OldTag "1.0.0" -NewTag "2.4.0"
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
