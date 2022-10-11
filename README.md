# Workflows

This repository contains reusable workflows and scripts to be used with GitHub Actions.

## Updater

Dependency updater - see [updater.yml](.github/workflows/updater.yml) - updates dependencies to the latest published git tag.

### Example workflow definition

```yaml
name: Update Dependencies
on:
  # Run every day.
  schedule:
    - cron: '0 3 * * *'
  # And on on every PR merge so we get the updated dependencies ASAP, and to make sure the changelog doesn't conflict.
  push:
    branches:
      - main
jobs:
  # Update a git submodule
  cocoa:
    uses: getsentry/github-workflows/.github/workflows/updater.yml@v2
    with:
      path: modules/sentry-cocoa
      name: Cocoa SDK
      pattern: '^1\.'  # Limit to major version '1'
    secrets:
      api-token: ${{ secrets.CI_DEPLOY_KEY }}

  # Update a properties file
  cli:
    uses: getsentry/github-workflows/.github/workflows/updater.yml@v2
    with:
      path: sentry-cli.properties
      name: CLI
    secrets:
      api-token: ${{ secrets.CI_DEPLOY_KEY }}

  # Update using a custom shell script, see updater/scripts/update-dependency.ps1 for the required arguments
  agp:
    uses: getsentry/github-workflows/.github/workflows/updater.yml@v2
    with:
      path: script.ps1
      name: Gradle Plugin
    secrets:
      api-token: ${{ secrets.CI_DEPLOY_KEY }}
```

### Inputs

* `path`: Dependency path in the source repository, this can be either a submodule, a .properties file or a shell script.
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
* `runs-on`: GitHub Actions virtual environment name to run the udpater job on.
  * type: string
  * required: false
  * default: ubuntu-latest
* `pr-strategy`: How to handle PRs.
  Can be either of the following:
  * `create` (default) - create a new PR for new dependency versions as they are released - maintainers may merge or close older PRs manually
  * `update` - keep a single PR that gets updated with new dependency versions until merged - only the latest version update is available at any time

### Secrets

* `api-token`: GH authentication token to create PRs with & push.
  If you provide the usual `${{ github.token }}`, no followup CI will run on the created PR.
  If you want CI to run on the PRs created by the Updater, you need to provide custom user-specific auth token.

## Danger

Runs DangerJS on Pull Reqeusts in your repository. This uses custom set of rules defined in [this dangerfile](danger/dangerfile.js).

```yaml
name: Danger

on:
  pull_request:
    types: [opened, synchronize, reopened, edited, ready_for_review]

jobs:
  danger:
    uses: getsentry/github-workflows/.github/workflows/danger.yml@v2
```
