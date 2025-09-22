# Danger Composite Action

Runs DangerJS on Pull Requests in your repository. This uses custom set of rules defined in [dangerfile.js](dangerfile.js).

## Usage

```yaml
name: Danger

on:
  pull_request:
    types: [opened, synchronize, reopened, edited, ready_for_review, labeled, unlabeled]

jobs:
  danger:
    runs-on: ubuntu-latest
    steps:
      - uses: getsentry/github-workflows/danger@v3
```

## Inputs

* `api-token`: Token for the repo. Can be passed in using `${{ secrets.GITHUB_TOKEN }}`.
  * type: string
  * required: false
  * default: `${{ github.token }}`

## Outputs

* `outcome`: Whether the Danger run finished successfully. Possible values are `success`, `failure`, `cancelled`, or `skipped`.

## Migration from v2 Reusable Workflow

If you're migrating from the v2 reusable workflow, see the [changelog migration guide](../CHANGELOG.md#unreleased) for detailed examples.

Key changes:
- Add `runs-on` to specify the runner
- No need for explicit `actions/checkout` step (handled internally)
- Optional `api-token` input (defaults to `github.token`)

## Rules

The Danger action runs the following checks:

- **Changelog validation**: Ensures PRs include appropriate changelog entries
- **Action pinning**: Verifies GitHub Actions are pinned to specific commits for security
- **Conventional commits**: Validates commit message format and PR title conventions
- **Cross-repo links**: Checks for proper formatting of links in changelog entries

For detailed rule implementations, see [dangerfile.js](dangerfile.js).