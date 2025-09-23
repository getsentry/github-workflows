
Describe 'get-changelog' {
    It 'with existing versions' {
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/getsentry/github-workflows' -OldTag 'v2.0.0' -NewTag 'v2.1.0'
        $expected = @'
## Changelog

### 2.1.0

#### Features

- New reusable workflow, `danger.yml`, to check Pull Requests with predefined rules ([#34](https://github-redirect.dependabot.com/getsentry/github-workflows/pull/34))
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

    It 'Does not show versions older than OldTag even if OldTag is missing' {
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/getsentry/github-workflows' -OldTag 'v2.1.1' -NewTag 'v2.2.1'
        $actual | Should -Be @'
## Changelog

### 2.2.1

#### Fixes

- Support comments when parsing pinned actions in Danger ([#40](https://github-redirect.dependabot.com/getsentry/github-workflows/pull/40))


### 2.2.0

#### Features

- Danger - check for that actions are pinned to a commit ([#39](https://github-redirect.dependabot.com/getsentry/github-workflows/pull/39))
'@
    }

    It 'truncates too long text' {
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/getsentry/sentry-cli' -OldTag '1.60.0' -NewTag '2.32.0'
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

    It 'supports cross-repo links' {
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/getsentry/sentry-native' -OldTag '0.7.17' -NewTag '0.7.18'
        $expected = @'
## Changelog

### 0.7.18

**Features**:

- Add support for Xbox Series X/S. ([#1100](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1100))
- Add option to set debug log level. ([#1107](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1107))
- Add `traces_sampler` ([#1108](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1108))
- Provide support for C++17 compilers when using the `crashpad` backend. ([#1110](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1110), [crashpad#116](https://github-redirect.dependabot.com/getsentry/crashpad/pull/116), [mini_chromium#1](https://github-redirect.dependabot.com/getsentry/mini_chromium/pull/1))
'@

        $actual | Should -Be $expected
    }

    It 'handles commit SHA as OldTag by resolving to tag' {
        # Test with a SHA that corresponds to a known tag (0.9.1)
        # This should resolve the SHA to the tag and use normal changelog logic
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/getsentry/sentry-native' `
            -OldTag 'a64d5bd8ee130f2cda196b6fa7d9b65bfa6d32e2' `
            -NewTag '0.11.0'

        $expected = @'
## Changelog

### 0.11.0

**Breaking changes**:

- Add `user_data` parameter to `traces_sampler`. ([#1346](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1346))

**Fixes**:

- Include `stddef.h` explicitly in `crashpad` since future `libc++` revisions will stop providing this include transitively. ([#1375](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1375), [crashpad#132](https://github-redirect.dependabot.com/getsentry/crashpad/pull/132))
- Fall back on `JWASM` in the _MinGW_ `crashpad` build only if _no_ `CMAKE_ASM_MASM_COMPILER` has been defined. ([#1375](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1375), [crashpad#133](https://github-redirect.dependabot.com/getsentry/crashpad/pull/133))
- Prevent `crashpad` from leaking Objective-C ARC compile options into any parent target linkage. ([#1375](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1375), [crashpad#134](https://github-redirect.dependabot.com/getsentry/crashpad/pull/134))
- Fixed a TOCTOU race between session init/shutdown and event capture. ([#1377](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1377))
- Make the Windows resource generation aware of config-specific output paths for multi-config generators. ([#1383](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1383))
- Remove the `ASM` language from the top-level CMake project, as this triggered CMake policy `CMP194` which isn't applicable to the top-level. ([#1384](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1384))

**Features**:

- Add a configuration to disable logging after a crash has been detected - `sentry_options_set_logger_enabled_when_crashed()`. ([#1371](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1371))

**Internal**:

- Support downstream Xbox SDK specifying networking initialization mechanism. ([#1359](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1359))
- Added `crashpad` support infrastructure for the external crash reporter feature. ([#1375](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1375), [crashpad#131](https://github-redirect.dependabot.com/getsentry/crashpad/pull/131))

**Docs**:

- Document the CMake 4 requirement on macOS `SDKROOT` due to its empty default for `CMAKE_OSX_SYSROOT` in the `README`. ([#1368](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1368))

**Thank you**:

- [JanFellner](https://github-redirect.dependabot.com/JanFellner)

### 0.10.1

**Internal**:

- Correctly apply dynamic mutex initialization in unit-tests (fixes running unit-tests in downstream console SDKs). ([#1337](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1337))

### 0.10.0

**Breaking changes**:

- By using transactions as automatic trace boundaries, transactions will, by default, no longer be part of the same singular trace. This is not the case when setting trace boundaries explicitly (`sentry_regenerate_trace()` or `sentry_set_trace()`), which turns off the automatic management of trace boundaries. ([#1270](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1270))
- Change transaction sampling to be trace-based. This does not affect you when transactions are used for automatic trace boundaries (as described above), since every transaction is part of a new trace. However, if you manage trace boundaries manually (using `sentry_regenerate_trace()`) or run the Native SDK inside a downstream SDK like the Unity SDK, where these SDKs will manage the trace boundaries, for a given `traces_sample_rate`, either all transactions in a trace get sampled or none do with probability equal to that sample rate. ([#1254](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1254))
- Moved Xbox toolchains to an Xbox-specific repository [sentry-xbox](https://github-redirect.dependabot.com/getsentry/sentry-xbox). You can request access to the repository by following the instructions in [Xbox documentation](https://docs.sentry.io/platforms/xbox/). ([#1329](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1329))

**Features**:

- Add `sentry_clear_attachments()` to allow clearing all previously added attachments in the global scope. ([#1290](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1290))
- Automatically set trace boundaries with every transaction. ([#1270](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1270))
- Provide `sentry_regenerate_trace()` to allow users to set manual trace boundaries. ([#1293](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1293))
- Add `Dynamic Sampling Context (DSC)` to events. ([#1254](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1254))
- Add `sentry_value_new_feedback` and `sentry_capture_feedback` to allow capturing [User Feedback](https://develop.sentry.dev/sdk/data-model/envelope-items/#user-feedback). ([#1304](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1304))
  - Deprecate `sentry_value_new_user_feedback` and `sentry_capture_user_feedback` in favor of the new API.
- Add `sentry_envelope_read_from_file`, `sentry_envelope_get_header`, and `sentry_capture_envelope`. ([#1320](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1320))
- Add `(u)int64` `sentry_value_t` type. ([#1326](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1326))

**Meta**:

- Marked deprecated functions with `SENTRY_DEPRECATED(msg)`. ([#1308](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1308))

**Internal**:

- Crash events from Crashpad now have `event_id` defined similarly to other backends. This makes it possible to associate feedback at the time of crash. ([#1319](https://github-redirect.dependabot.com/getsentry/sentry-native/pull/1319))
'@

        $actual | Should -Be $expected
    }

    It 'handles commit SHA as OldTag by getting changelog diff when SHA does not map to tag' {
        # Test with a SHA that doesn't correspond to any tag - should use diff approach
        # This SHA is between v2.8.0 and v2.8.1 in github-workflows repo
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/getsentry/github-workflows' `
            -OldTag 'cc24e8eb3c13d3d2e949f4a20c86d2ccac310c11' `
            -NewTag 'v2.8.1'

        $expected = @'
## Changelog

### 2.8.1
#### Fixes
- Sentry-CLI integration test - set server script root so assets access works.  ([#63](https://github-redirect.dependabot.com/getsentry/github-workflows/pull/63))

<details>
<summary>Full CHANGELOG.md diff</summary>

```diff
 -1,12 +1,10
 # Changelog

-## Unreleased
+## 2.8.1

-### Dependencies
+### Fixes

-- Bump CLI from v2.0.0 to v2.0.4 ([#60](https://github-redirect.dependabot.com/getsentry/github-workflows/pull/60))
-  - [changelog](https://github-redirect.dependabot.com/getsentry/sentry-cli/blob/master/CHANGELOG.md[#204](https://github-redirect.dependabot.com/getsentry/github-workflows/issues/204))
-  - [diff](https://github-redirect.dependabot.com/getsentry/sentry-cli/compare/2.0.0...2.0.4)
+- Sentry-CLI integration test - set server script root so assets access works.  ([#63](https://github-redirect.dependabot.com/getsentry/github-workflows/pull/63))

 ## 2.8.0

```

</details>
'@

        # there's an issue with line endings so we'll compare line by line
        $actualLines = $actual -split "`n"
        $expectedLines = $expected -split "`n"
        $actualLines.Count | Should -Be $expectedLines.Count
        for ($i = 0; $i -lt $actualLines.Count; $i++) {
            $actualLines[$i].Trim() | Should -Be $expectedLines[$i].Trim()
        }
    }

    It 'falls back to git commits when no changelog files exist' {
        # Test with a repository that doesn't have changelog files
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/catchorg/Catch2' -OldTag 'v3.9.1' -NewTag 'v3.10.0'

        $expected = @'
## Changelog

### Commits between v3.9.1 and v3.10.0

- Forbid deducing reference types for m_predicate in FilterGenerator ([#3005](https://github-redirect.dependabot.com/catchorg/Catch2/issues/3005))
- Make message macros (FAIL, WARN, INFO, etc) thread safe
- Improve performance of writing XML
- Improve performance of writing JSON values
- Don't add / to start of pkg-config file path when DESTDIR is unset
- Fix color mode detection on FreeBSD by adding platform macro
- Handle DESTDIR env var when generating pkgconfig files
'@

        $actual | Should -Be $expected
    }

    It 'git commit fallback handles PR references correctly' {
        # Test with a known repository and tags that contain PR references
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/catchorg/Catch2' -OldTag 'v3.9.1' -NewTag 'v3.10.0'

        # This test verifies the same content as the main test, but focuses on PR link formatting
        $expected = @'
## Changelog

### Commits between v3.9.1 and v3.10.0

- Forbid deducing reference types for m_predicate in FilterGenerator ([#3005](https://github-redirect.dependabot.com/catchorg/Catch2/issues/3005))
- Make message macros (FAIL, WARN, INFO, etc) thread safe
- Improve performance of writing XML
- Improve performance of writing JSON values
- Don't add / to start of pkg-config file path when DESTDIR is unset
- Fix color mode detection on FreeBSD by adding platform macro
- Handle DESTDIR env var when generating pkgconfig files
'@

        $actual | Should -Be $expected
    }

    It 'git commit fallback returns empty when no commits found' {
        # Test with same tags (no commits between them)
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/catchorg/Catch2' -OldTag 'v3.10.0' -NewTag 'v3.10.0'

        $actual | Should -BeNullOrEmpty
    }

    It 'git commit fallback filters out version tag commits' {
        # Test that version commits like "v3.10.0" are filtered out
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/catchorg/Catch2' -OldTag 'v3.9.0' -NewTag 'v3.10.0'

        # Expected output should not contain version tag commits but should have meaningful commits
        # This range includes v3.9.1 and v3.10.0 version commits that should be filtered out
        $expected = @'
## Changelog

### Commits between v3.9.0 and v3.10.0

- Forbid deducing reference types for m_predicate in FilterGenerator ([#3005](https://github-redirect.dependabot.com/catchorg/Catch2/issues/3005))
- Make message macros (FAIL, WARN, INFO, etc) thread safe
- Improve performance of writing XML
- Improve performance of writing JSON values
- Don't add / to start of pkg-config file path when DESTDIR is unset
- Fix color mode detection on FreeBSD by adding platform macro
- Handle DESTDIR env var when generating pkgconfig files
- Add tests for comparing & stringifying volatile pointers
- Refactor CATCH_TRAP selection logic to prefer compiler-specific impls
- Update generators.md
- Cleanup WIP changes from last commit
- Catch exceptions from StringMakers inside Detail::stringify
- Fix StringMaker for time_point<system_clock> with non-default duration
- Fix warning in `catch_unique_ptr::bool()`
- Add enum types to what is captured by value by default
- Don't follow __assume(false) with std::terminate in NDEBUG builds
- Fix bad error reporting for nested exceptions in default configuration
'@

        $actual | Should -Be $expected
    }

    It 'git commit fallback handles invalid repository gracefully' {
        # Test with a non-existent repository to verify error handling
        $actual = & "$PSScriptRoot/../scripts/get-changelog.ps1" `
            -RepoUrl 'https://github.com/nonexistent/repository' -OldTag 'v1.0.0' -NewTag 'v2.0.0'

        # Should return empty/null and not crash the script
        $actual | Should -BeNullOrEmpty
    }
}
