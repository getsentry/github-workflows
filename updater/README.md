# Updater Composite Action

Dependency updater - updates dependencies to the latest published git tag and creates/updates PRs.

## Usage

```yaml
name: Update Dependencies
on:
  # Run every day.
  schedule:
    - cron: '0 3 * * *'
  # And on every PR merge so we get the updated dependencies ASAP, and to make sure the changelog doesn't conflict.
  push:
    branches:
      - main

jobs:
  # Update a git submodule
  cocoa:
    runs-on: ubuntu-latest
    steps:
      - uses: getsentry/github-workflows/updater@v3
        with:
          path: modules/sentry-cocoa
          name: Cocoa SDK
          pattern: '^1\.'  # Limit to major version '1'
          api-token: ${{ secrets.CI_DEPLOY_KEY }}

  # Update a properties file
  cli:
    runs-on: ubuntu-latest
    steps:
      - uses: getsentry/github-workflows/updater@v3
        with:
          path: sentry-cli.properties
          name: CLI
          api-token: ${{ secrets.CI_DEPLOY_KEY }}

  # Update using a custom shell script, see updater/scripts/update-dependency.ps1 for the required arguments
  agp:
    runs-on: ubuntu-latest
    steps:
      - uses: getsentry/github-workflows/updater@v3
        with:
          path: script.ps1
          name: Gradle Plugin
          api-token: ${{ secrets.CI_DEPLOY_KEY }}

  # Update a CMake FetchContent dependency with auto-detection (single dependency only)
  sentry-native:
    runs-on: ubuntu-latest
    steps:
      - uses: getsentry/github-workflows/updater@v3
        with:
          path: vendor/sentry-native.cmake
          name: Sentry Native SDK
          api-token: ${{ secrets.CI_DEPLOY_KEY }}

  # Update a CMake FetchContent dependency with explicit dependency name
  deps:
    runs-on: ubuntu-latest
    steps:
      - uses: getsentry/github-workflows/updater@v3
        with:
          path: vendor/dependencies.cmake#googletest
          name: GoogleTest
          api-token: ${{ secrets.CI_DEPLOY_KEY }}
```

## Inputs

* `path`: Dependency path in the source repository. Supported formats:
  * Submodule path
  * Properties file (`.properties`)
  * Shell script (`.ps1`, `.sh`)
  * CMake file with FetchContent:
    * `path/to/file.cmake#DepName` - specify dependency name
    * `path/to/file.cmake` - auto-detection (single dependency only)
  * type: string
  * required: true
* `name`: Name used in the PR title and the changelog entry.
  * type: string
  * required: true
* `pattern`: RegEx pattern that will be matched against available versions when picking the latest one.
  * type: string
  * required: false
  * default: ''
* `changelog-entry`: Whether to add a changelog entry for the update.
  * type: boolean
  * required: false
  * default: true
* `changelog-section`: Section header to attach the changelog entry to.
  * type: string
  * required: false
  * default: Dependencies
* `pr-strategy`: How to handle PRs.
  Can be either of the following:
  * `create` (default) - create a new PR for new dependency versions as they are released - maintainers may merge or close older PRs manually
  * `update` - keep a single PR that gets updated with new dependency versions until merged - only the latest version update is available at any time
* `api-token`: Token for the repo. Can be passed in using `${{ secrets.GITHUB_TOKEN }}`.
  If you provide the usual `${{ github.token }}`, no followup CI will run on the created PR.
  If you want CI to run on the PRs created by the Updater, you need to provide custom user-specific auth token.
  * type: string
  * required: true

## Outputs

* `prUrl`: The created/updated PR's URL.
* `baseBranch`: The base branch name.
* `prBranch`: The created/updated PR branch name.
* `originalTag`: The original tag from which the dependency was updated from.
* `latestTag`: The latest tag to which the dependency was updated to.

## Migration from v2 Reusable Workflow

If you're migrating from the v2 reusable workflow, see the [changelog migration guide](../CHANGELOG.md#unreleased) for detailed examples.

Key changes:
- Add `runs-on` to specify the runner
- Move `secrets.api-token` to `with.api-token`
- No need for explicit `actions/checkout` step (handled internally)