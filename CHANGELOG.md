# Changelog

## Unreleased

### Breaking Changes

- Updater: The default value for `pr-strategy` has been changed from `create` to `update`.
  This change means the updater will now maintain a single PR that gets updated with new dependency versions (instead of creating separate PRs for each version).
  If you want to preserve the previous behavior of creating separate PRs, explicitly set `pr-strategy: create` in your workflow:

  ```yaml
  - uses: getsentry/github-workflows/updater@v3
    with:
      # ... other inputs ...
      pr-strategy: create  # Add this to preserve previous behavior
  ```

  In case you have existing open PRs created with the `create` strategy, you will need to remove these old branches
  manually as the new name would be a prefix of the old PRs, which git doesnt' allow.

- Updater and Danger reusable workflows are now composite actions ([#114](https://github.com/getsentry/github-workflows/pull/114))

  To update your existing Updater workflows:
  ```yaml
  ### Before
    native:
      uses: getsentry/github-workflows/.github/workflows/updater.yml@v2
      with:
        path: scripts/update-sentry-native-ndk.sh
        name: Native SDK
      secrets:
        # If a custom token is used instead, a CI would be triggered on a created PR.
        api-token: ${{ secrets.CI_DEPLOY_KEY }}

  ### After
    native:
      runs-on: ubuntu-latest
      steps:
        - uses: getsentry/github-workflows/updater@v3
          with:
            path: scripts/update-sentry-native-ndk.sh
            name: Native SDK
            api-token: ${{ secrets.CI_DEPLOY_KEY }}
  ```

  To update your existing Danger workflows:
  ```yaml
  ### Before
    danger:
      uses: getsentry/github-workflows/.github/workflows/danger.yml@v2

  ### After
    danger:
      runs-on: ubuntu-latest
      steps:
        - uses: getsentry/github-workflows/danger@v3
  ```

### Features

- Updater now supports targeting non-default branches via the new `target-branch` input parameter ([#118](https://github.com/getsentry/github-workflows/pull/118))
- Updater now supports filtering releases by GitHub release title patterns, e.g. to support release channels ([#117](https://github.com/getsentry/github-workflows/pull/117))
- Updater now supports dependencies without changelog files by falling back to git commit messages ([#116](https://github.com/getsentry/github-workflows/pull/116))
- Danger - Improve conventional commit scope handling, and non-conventional PR title support ([#105](https://github.com/getsentry/github-workflows/pull/105))
- Add Proguard artifact endpoint for Android builds in sentry-server ([#100](https://github.com/getsentry/github-workflows/pull/100))
- Updater - Add CMake FetchContent support for automated dependency updates ([#104](https://github.com/getsentry/github-workflows/pull/104))

### Security

- Updater - Prevent script injection vulnerabilities through workflow inputs ([#98](https://github.com/getsentry/github-workflows/pull/98))

### Fixes

- Improve changelog generation for non-tagged commits and edge cases ([#115](https://github.com/getsentry/github-workflows/pull/115))

## 2.14.1

### Fixes

- Use GITHUB_WORKFLOW_REF instead of _workflow_version input parameter to automatically determine workflow script versions ([#109](https://github.com/getsentry/github-workflows/pull/109))

## 2.14.0

### Features

- Danger - Improve conventional commit scope handling, and non-conventional PR title support ([#105](https://github.com/getsentry/github-workflows/pull/105))
- Add Proguard artifact endpoint for Android builds in sentry-server ([#100](https://github.com/getsentry/github-workflows/pull/100))
- Updater - Add CMake FetchContent support for automated dependency updates ([#104](https://github.com/getsentry/github-workflows/pull/104))

### Security

- Updater - Prevent script injection vulnerabilities through workflow inputs ([#98](https://github.com/getsentry/github-workflows/pull/98))

## 2.13.1

### Fixes

- Updater - invalid workflow syntax - reverts recent switch to env vars ([#97](https://github.com/getsentry/github-workflows/pull/97))

## 2.13.0

### Features

- Danger - Changelog checks can now additionally be skipped with a `skip-changelog` label ([#94](https://github.com/getsentry/github-workflows/pull/94))

## 2.12.0

### Features

- Gzip-compressed HTTP requests ([#88](https://github.com/getsentry/github-workflows/pull/88))

### Fixes

- Don't update from a manually-updated prerelease to a latest stable release that is earlier than the prerelease ([#78](https://github.com/getsentry/github-workflows/pull/78))
- Cross-repo links in changelog notes ([#82](https://github.com/getsentry/github-workflows/pull/82))
- Truncate changelog to nearest SemVer even if actual previous version is missing ([#84](https://github.com/getsentry/github-workflows/pull/84))

## 2.11.0

### Features

- Add support for prettier-ignore notes on `CHANGELOG.md` ([#75](https://github.com/getsentry/github-workflows/pull/75))

Example of notes before `## Unreleased` Header on `CHANGELOG.md`

<!-- prettier-ignore-start -->
> [!IMPORTANT]
> If you are upgrading to the `1.x` versions of the Sentry SDK from `0.x` or below,
> make sure you follow our [migration guide](https://docs.sentry.io/platforms/SDK/migration/) first.
<!-- prettier-ignore-end -->

## 2.10.0

### Changes

- Remove `octokit/request-action` dependency in favor of using `gh api` ([#74](https://github.com/getsentry/github-workflows/pull/74))

### Fixes

- Bump updater action dependency to fix an issue when creating/updating a PR ([#71](https://github.com/getsentry/github-workflows/pull/71))

### Dependencies

- Bump `actions/checkout` from v3 to v4 ([#72](https://github.com/getsentry/github-workflows/pull/72))
- Bump `styfle/cancel-workflow-action` from v0.12.0 to v0.12.1 ([#73](https://github.com/getsentry/github-workflows/pull/73))

## 2.9.1

### Fixes

- Danger - fix pinned action check if the ref is at the end of the file ([#70](https://github.com/getsentry/github-workflows/pull/70))

## 2.9.0

### Fixes

- Danger - recognize PR links based on full URL instead of just the PR number. ([#68](https://github.com/getsentry/github-workflows/pull/68))

### Dependencies

- Bump `danger/danger-js` from v11.1.2 to v11.3.1 ([#59](https://github.com/getsentry/github-workflows/pull/59))

## 2.8.1

### Fixes

- Sentry-CLI integration test - set server script root so assets access works.  ([#63](https://github.com/getsentry/github-workflows/pull/63))

## 2.8.0

### Fixes

- Updater - non-bot commit-checks in PRs for SSH repository URLs (starting with `git@github.com:`) ([#62](https://github.com/getsentry/github-workflows/pull/62))

### Features

- Sentry-CLI integration test action: support envelopes ([#58](https://github.com/getsentry/github-workflows/pull/58))

### Dependencies

- Bump updater action dependencies ([#61](https://github.com/getsentry/github-workflows/pull/61))

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
