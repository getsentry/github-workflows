# Validate PR

Advisory validation for non-maintainer pull requests against contribution guidelines. Posts a single friendly comment when a PR doesn't reference an issue with prior maintainer discussion. **PRs are never closed, and no labels are applied.**

## What it does

For PRs from non-maintainer authors, the action checks that the PR body references a GitHub issue where the PR author and a maintainer have discussed the approach. When that's not the case, the action posts one short advisory comment inviting the contributor to start with an issue. Maintainers (`admin` or `maintain` role) and a hard-coded list of trusted bots are exempt.

Small PRs (< 100 lines changed, excluding lock files) are skipped entirely — typo fixes and tiny bug fixes don't need to go through the issue-discussion loop.

## Usage

Create `.github/workflows/validate-pr.yml` in your repository:

```yaml
name: Validate PR

on:
  pull_request_target:
    types: [opened]

jobs:
  validate-pr:
    runs-on: ubuntu-24.04
    permissions:
      pull-requests: write
    steps:
      - uses: getsentry/github-workflows/validate-pr@<sha>
        with:
          app-id: ${{ vars.SDK_MAINTAINER_BOT_APP_ID }}
          private-key: ${{ secrets.SDK_MAINTAINER_BOT_PRIVATE_KEY }}
```

Pin to a specific commit SHA (consumers in `getsentry/*` already follow this convention). The `pull-requests: write` permission is needed because the action posts comments on the PR.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `app-id` | Yes | GitHub App ID for the SDK Maintainer Bot |
| `private-key` | Yes | GitHub App private key for the SDK Maintainer Bot |

## Validation rules

### Skipped entirely

- PR author is in the trusted-bot allowlist (Dependabot, Renovate, Codecov AI, etc.)
- PR author has `admin`, `maintain`, `push`, or `write` access on the repo
- PR has fewer than 100 lines changed (`additions + deletions`), excluding common lock files

### Lock files excluded from line counts

Matched by basename, case-insensitive:

| Ecosystem | File |
|-----------|------|
| Rust | `Cargo.lock` |
| JS | `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` |
| Python | `Pipfile.lock`, `poetry.lock`, `uv.lock` |
| Ruby | `Gemfile.lock` |
| PHP | `composer.lock` |
| Go | `go.sum` (`go.mod` is hand-edited and stays counted) |
| Elixir | `mix.lock` |
| Dart/Flutter | `pubspec.lock` |
| .NET/NuGet | `packages.lock.json` |
| CocoaPods | `Podfile.lock` |
| Nix | `flake.lock` |

### Issue reference check

For PRs that reach validation, the action scans the PR body for issue references in these formats:

- `#123` (same-repo)
- `getsentry/repo#123` (cross-repo)
- `https://github.com/getsentry/repo/issues/123` (full URL)
- With optional keywords: `Fixes #123`, `Closes getsentry/repo#123`, etc.

The PR is considered compliant if **any** referenced issue passes all of:

- The issue is fetchable and in a `getsentry` repository
- If the issue has assignees, the PR author is one of them
- Both the PR author and a maintainer have participated in the issue discussion

If no referenced issue passes, the action posts one advisory comment. The PR remains open and reviewable; no labels or status checks are applied. The comment is idempotent — workflow re-runs on the same PR will not produce duplicates.

## Updating from earlier revisions

Earlier revisions of this action closed non-compliant PRs and applied labels (`violating-contribution-guidelines`, `missing-issue-reference`, `missing-maintainer-discussion`, `issue-already-assigned`). The current version does neither — it only posts a comment.

To update an existing consumer:

- Bump the pinned commit SHA to the latest on `main`.
- Change `types: [opened, reopened]` → `types: [opened]`.
- Remove any code that reads the `was-closed` output (it no longer exists).

Existing labels on old PRs are not removed automatically. Clean them up with a one-off script if desired.
