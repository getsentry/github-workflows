# Changelog

## Unreleased

### Features

- Sentry-CLI integration test action: support envelopes ([#58](https://github.com/getsentry/github-workflows/pull/58))

### Dependencies

- Bump TARGET-BRANCH-TEST-DO-NOT-MERGE from v2.0.0 to v2.0.4 ([#121](https://github.com/getsentry/github-workflows/pull/121))
  - [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#204)
  - [diff](https://github.com/getsentry/sentry-cli/compare/2.0.0...2.0.4)

## 2.7.0

### Features

- Sentry-CLI integration test action ([#54](https://github.com/getsentry/github-workflows/pull/54))

## 2.6.0

### Features

- Danger - add "github" to the list of whitelisted users for action-pinning check ([#55](https://github.com/getsentry/github-workflows/pull/55))

## 2.5.1

### Fixes

- Updater - exit code in PR commit check if the PR doesn't exist yet ([#51](https://github.com/getsentry/github-workflows/pull/51))

## 2.5.0

### Features

- Updater - don't update existing branches if there are manually added commits ([#50](https://github.com/getsentry/github-workflows/pull/50))
- Danger - ignore "deps" and "test" PR flavors in changelog checks ([#49](https://github.com/getsentry/github-workflows/pull/49))

### Fixes

- Updater - update deprecated actions ([#48](https://github.com/getsentry/github-workflows/pull/48))

## 2.4.0

### Features

- Danger - check that a changelog entry is not added to an already released section ([#44](https://github.com/getsentry/github-workflows/pull/44))

## 2.3.0

### Features

- Updater - add `changelog-entry` option to disable adding a changelog entry ([#43](https://github.com/getsentry/github-workflows/pull/43))

## 2.2.2

### Fixes

- Skip local actions when checking pinned actions in Danger ([#41](https://github.com/getsentry/github-workflows/pull/41))

## 2.2.1

### Fixes

- Support comments when parsing pinned actions in Danger ([#40](https://github.com/getsentry/github-workflows/pull/40))

## 2.2.0

### Features

- Danger - check for that actions are pinned to a commit ([#39](https://github.com/getsentry/github-workflows/pull/39))

## 2.1.1

### Fixes

- Show GitHub annotations when running from forks - can't post a PR comment in that case ([#37](https://github.com/getsentry/github-workflows/pull/37))

## 2.1.0

### Features

- New reusable workflow, `danger.yml`, to check Pull Requests with predefined rules ([#34](https://github.com/getsentry/github-workflows/pull/34))

## 2.0.0

### Changes

- Rename `api_token` secret to `api-token` ([#21](https://github.com/getsentry/github-workflows/pull/21))
- Change changelog target section header from "Features" to "Dependencies" ([#19](https://github.com/getsentry/github-workflows/pull/19))

### Features

- Add `pr-strategy` switch to choose between creating new PRs or updating an existing one ([#22](https://github.com/getsentry/github-workflows/pull/22))
- Add `changelog-section` input setting to specify target changelog section header ([#19](https://github.com/getsentry/github-workflows/pull/19))

### Fixes

- Preserve changelog bullet-point format ([#20](https://github.com/getsentry/github-workflows/pull/20))
- Changelog section parsing when an entry text contains the section name in the text ([#25](https://github.com/getsentry/github-workflows/pull/25))

## 1.0.0

Initial release & subsequent fixes - only major version v1 was kept & overridden for this release.
