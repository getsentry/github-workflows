# Skip CI

Tells whether a push to a pull request only changes files that need no CI, such as Markdown, since a head whose CI passed. Jobs gated on its `skip` output then don't run for a CHANGELOG fix-up or a docs edit, while everything else runs as usual.

A workflow's `paths-ignore` can't do this: GitHub matches it against the whole pull request, so a pull request that changes code runs the full workflow on every later push, even one that only touches `CHANGELOG.md`.

## Usage

Add a job that runs the action, and gate the expensive jobs on its output:

```yaml
jobs:
  changes:
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
    outputs:
      skip: ${{ steps.skip-ci.outputs.skip }}
    steps:
      - id: skip-ci
        uses: getsentry/github-workflows/skip-ci@<sha>
        with:
          paths: |
            **/*.md
            !package/**

  build:
    needs: [changes]
    if: ${{ needs.changes.outputs.skip != 'true' }}
    runs-on: ubuntu-latest
    steps:
      - run: echo "build and test"
```

Pin to a specific commit SHA. Jobs that depend on a skipped job through `needs` skip with it, so gating the jobs everything else starts from is enough. Every job that waits on another one's artifacts must be gated too, or it waits for artifacts that never come.

The job needs `actions: read` to find earlier runs and `contents: read` to compare commits. Without them the API calls fail, the action logs a warning, and CI runs.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `paths` | No | Patterns, one per line, of files whose changes alone need no CI. Default: `**/*.md`. |
| `api-token` | No | Token for the repo. Default: `${{ github.token }}`. |

## Outputs

| Output | Description |
|--------|-------------|
| `skip` | `true` when the jobs gated on this check can be skipped, `false` otherwise. |

## When it skips

`skip` is `true` only when all of these hold:

- The workflow runs for a `pull_request` event with the `synchronize` action, i.e. a push to an open pull request. Any other event, including `push`, `workflow_dispatch`, `merge_group` and `pull_request_target`, gives `false`.
- The same workflow has a successful run for the previous head of the pull request, on the same branch of the same repository. A run that skipped its jobs through this action counts, because it was itself checked against a head that passed.
- The new head is strictly ahead of the previous head. A force-push that dropped or rewrote commits gives `false`.
- Between 1 and 299 files changed between the two heads (the compare API lists at most 300), and every changed file matches `paths`. For a renamed file, both its new and its old name must match.

When any API call fails, the action logs a warning and gives `false`. It never fails the job.

When it skips, the action writes the reason to the job summary.

## Patterns

- `**` matches any characters, including `/`. A leading `**/` also matches files at the root, so `**/*.md` matches `CHANGELOG.md` and `docs/setup.md`.
- `*` matches any characters except `/`, so `*.md` matches only Markdown files at the root.
- `?` matches one character except `/`.
- A pattern starting with `!` takes matching files back out. The last pattern that matches a file decides, so `!package/**` after `**/*.md` keeps Markdown files under `package/` needing CI.
- Blank lines and lines starting with `#` are ignored. Matching is case-sensitive.

These are not GitHub's `paths` filter patterns: `?`, `+` and `[...]` mean something else there.

## Required status checks

A job skipped by its `if:` reports one check under its unexpanded name, such as `Build ${{ matrix.target }}`, instead of one per matrix entry. A required check that names a matrix entry then never reports, and the pull request can't be merged. If you require checks, require one job that always runs and checks the results of the others, not the gated jobs themselves.
