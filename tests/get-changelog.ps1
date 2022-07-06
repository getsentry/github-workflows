Set-StrictMode -Version latest

. "$PSScriptRoot/common/test-utils.ps1"

RunTest "get-changelog with existing versions" {
    $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
        -RepoUrl "https://github.com/getsentry/sentry-javascript" -OldTag "7.4.0" -NewTag "7.5.1"
    $expected = @'
## Changelog
### 7.5.1

This release removes the `user_id` and the `transaction` field from the dynamic sampling context data that is attached to outgoing requests as well as sent to Relay.

- ref(tracing): Remove transaction name and user_id from DSC (#5363)

### 7.5.0

This release adds the `sendDefaultPii` flag to the `Sentry.init` options.
When using performance monitoring capabilities of the SDK, it controls whether user IDs (set via `Sentry.setUser`) are propagated in the `baggage` header of outgoing HTTP requests.
This flag is set to `false` per default, and acts as an opt-in mechanism for sending potentially sensitive data.
If you want to attach user IDs to Sentry transactions and traces, set this flag to `true` but keep in mind that this is potentially sensitive information.

- feat(sdk): Add sendDefaultPii option to the JS SDKs (#5341)
- fix(remix): Sourcemaps upload script is missing in the tarball (#5356)
- fix(remix): Use cjs for main entry point (#5352)
- ref(tracing): Only add `user_id` to DSC if `sendDefaultPii` is `true` (#5344)

Work in this release contributed by jkcorrea and nfelger. Thank you for your contributions!

### 7.4.1

This release includes the first *published* version of `sentry/remix`.

- build(remix): Make remix package public (#5349)
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

- feat: Compute and upload il2cpp line mappings (#1248) by loewenheim
- ref: Skip protected zip files when uploading debug files (#1245) by kamilogorek
'@

    AssertEqual $expected $actual
}