# Changelog

## 2.3.0

### Features

- Updater - add `changelog-entry` option to disable adding a changelog entry ([#43](https://github.com/getsentry/github-workflows/pull/43))
- Danger - check a changelog entry is not added to an already released section ([#44](https://github.com/getsentry/github-workflows/pull/44))

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
