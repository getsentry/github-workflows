# Changelog

## Unreleased

### Dependencies

- Bump Workflow args test script from v2 to v1 ([#28](https://github.com/getsentry/github-workflows/pull/28))
  - [changelog](https://github.com/getsentry/github-workflows/blob/main/CHANGELOG.md#v1)
  - [diff](https://github.com/getsentry/github-workflows/compare/v2...v1)

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
