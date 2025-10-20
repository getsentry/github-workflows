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

permissions:
  contents: write      # To modify files and create commits
  pull-requests: write # To create and update pull requests
  actions: write       # To cancel previous workflow runs

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

  # Update to stable releases only by filtering GitHub release titles
  cocoa-stable:
    runs-on: ubuntu-latest
    steps:
      - uses: getsentry/github-workflows/updater@v3
        with:
          path: modules/sentry-cocoa
          name: Cocoa SDK (Stable)
          gh-title-pattern: '\(Stable\)$'  # Only releases with "(Stable)" suffix
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

  # Update dependencies on a non-default branch (e.g., alpha, beta, or version branches)
  # Note: due to limitations in GitHub Actions' schedule trigger, this code needs to be pushed to the default branch.
  cocoa-v7:
    runs-on: ubuntu-latest
    steps:
      - uses: getsentry/github-workflows/updater@v3
        with:
          path: modules/sentry-cocoa
          name: Cocoa SDK
          target-branch: v7
          pattern: '^1\.'  # Limit to major version '1'
          api-token: ${{ secrets.CI_DEPLOY_KEY }}

  # Use a post-update script (sh or ps1) to make additional changes after dependency update
  # The script receives two arguments: original version and new version
  post-update-script:
    runs-on: ubuntu-latest
    steps:
      - uses: getsentry/github-workflows/updater@v3
        with:
          path: modules/sentry-cocoa
          name: Cocoa SDK
          post-update-script: scripts/post-update.sh  # Receives args: $1=old version, $2=new version
          api-token: ${{ secrets.CI_DEPLOY_KEY }}

  # Authentication with SSH deploy key (git operations via SSH, API via default token)
  cocoa-ssh:
    runs-on: ubuntu-latest
    steps:
      - uses: getsentry/github-workflows/updater@v3
        with:
          path: modules/sentry-cocoa
          name: Cocoa SDK
          ssh-key: ${{ secrets.CI_DEPLOY_KEY }}

  # Authentication with both SSH key and API token (git via SSH, API via token)
  # This is useful when you need CI to run on created PRs and use a deploy key
  cocoa-ssh-and-token:
    runs-on: ubuntu-latest
    steps:
      - uses: getsentry/github-workflows/updater@v3
        with:
          path: modules/sentry-cocoa
          name: Cocoa SDK
          ssh-key: ${{ secrets.CI_DEPLOY_KEY }}
          api-token: ${{ secrets.CI_GITHUB_TOKEN }}
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
* `gh-title-pattern`: RegEx pattern to match against GitHub release titles. Only releases with matching titles will be considered. Useful for filtering to specific release channels (e.g., stable releases).
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
  * `create` - create a new PR for new dependency versions as they are released - maintainers may merge or close older PRs manually
  * `update` (default) - keep a single PR that gets updated with new dependency versions until merged - only the latest version update is available at any time
* `target-branch`: Branch to use as base for dependency updates. Defaults to repository default branch if not specified.
  * type: string
  * required: false
  * default: '' (uses repository default branch)
* `post-update-script`: Optional script to run after successful dependency update. Can be a bash script (`.sh`) or PowerShell script (`.ps1`). The script will be executed in the repository root directory before PR creation. The script receives two arguments:
  * `$1` / `$args[0]` - The original version (version before update)
  * `$2` / `$args[1]` - The new version (version after update)
  * type: string
  * required: false
  * default: ''
* `api-token`: GitHub API token for repository operations. Can be passed in using `${{ secrets.GITHUB_TOKEN }}`.
  If you provide the usual `${{ github.token }}`, no followup CI will run on the created PR.
  If you want CI to run on the PRs created by the Updater, you need to provide a custom user-specific auth token.
  Not required if `ssh-key` is provided, but can be used together with `ssh-key` for GitHub API operations.
  * type: string
  * required: false
  * default: ''
* `ssh-key`: SSH private key for repository authentication (e.g., deploy key). Can be used alone or together with `api-token`.
  When used alone, the action will use SSH for git operations and fall back to the default GitHub token for API operations.
  When used with `api-token`, SSH is used for git operations and the token is used for GitHub API operations.
  * type: string
  * required: false
  * default: ''

## Authentication

The updater supports multiple authentication methods. Choose based on your requirements:

### Option 1: API Token Only (Default)

```yaml
api-token: ${{ secrets.GITHUB_TOKEN }}
```

* **Use when**: Standard GitHub token authentication is sufficient
* **Limitation**: If using `${{ github.token }}`, CI workflows won't run on created PRs
* **Solution**: Use a personal access token or GitHub App token to enable CI on PRs

### Option 2: SSH Key Only

```yaml
ssh-key: ${{ secrets.CI_DEPLOY_KEY }}
```

* **Use when**: Repository access requires SSH (e.g., deploy keys)
* **Behavior**: Git operations use SSH (CI will run on PRs since commits are made with SSH key), API operations use default GitHub token

### Option 3: SSH Key + API Token (Recommended for Deploy Keys)

```yaml
ssh-key: ${{ secrets.CI_DEPLOY_KEY }}
api-token: ${{ secrets.CI_GITHUB_TOKEN }}
```

* **Use when**: You need both deploy key access AND want to control the API token used for GitHub operations
* **Behavior**: Git operations use SSH deploy key, API operations use provided token
* **Benefits**: Full control over authentication for both git and API operations

### Post-Update Script Example

**Bash script** (`scripts/post-update.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail

ORIGINAL_VERSION="$1"
NEW_VERSION="$2"

echo "Updated from $ORIGINAL_VERSION to $NEW_VERSION"
# Make additional changes to repository files here
```

**PowerShell script** (`scripts/post-update.ps1`):

```powershell
param(
    [Parameter(Mandatory = $true)][string] $OriginalVersion,
    [Parameter(Mandatory = $true)][string] $NewVersion
)

Write-Output "Updated from $OriginalVersion to $NewVersion"
# Make additional changes to repository files here
```

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
