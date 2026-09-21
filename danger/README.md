# Danger Composite Action

Runs DangerJS on Pull Requests in your repository. This uses custom set of rules defined in [dangerfile.js](dangerfile.js).

## Usage

```yaml
name: Danger

on:
  pull_request:
    types: [opened, synchronize, reopened, edited, ready_for_review, labeled, unlabeled]

permissions:
  contents: read       # To read repository files
  pull-requests: write # To post comments on pull requests
  statuses: write      # To post commit status checks

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

* `skip-checkout`: Set to `'true'` to reuse a repository checkout prepared by an earlier step. The caller must check out the repository with `fetch-depth: 0`. This preserves generated files and other workspace changes that the action's checkout would reset or remove.
  * type: string
  * required: false
  * default: `'false'`

* `extra-dangerfile`: Path to an additional dangerfile to run custom checks.
  * type: string
  * required: false
  * default: ""

* `extra-install-packages`: Additional packages that are required by the extra-dangerfile, you can find a list of packages here: https://packages.debian.org/search?suite=bookworm&keywords=curl.
  * type: string
  * required: false
  * default: ""

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

## Extra Danger File

If an earlier step generates your extra dangerfile, skip the action's checkout so it does not delete the generated file:

```yaml
steps:
  - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
    with:
      fetch-depth: 0

  - run: node scripts/generate-dangerfile.js

  - uses: getsentry/github-workflows/danger@v3
    with:
      skip-checkout: 'true'
      extra-dangerfile: '.github/generated-dangerfile.js'
```

When using an extra dangerfile, the file must be inside the repository and written in CommonJS syntax. You can use the following snippet to export your dangerfile:

```JavaScript
module.exports = async function ({ fail, warn, message, markdown, danger }) {
  ...
  const gitUrl = danger.github.pr.head.repo.git_url;
  ...
  warn('...');
}

```
