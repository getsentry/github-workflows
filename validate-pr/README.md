# Validate PR

Validates non-maintainer pull requests against contribution guidelines.

## What it does

1. **Validates issue references** — Non-maintainer PRs must reference a GitHub issue where the PR author and a maintainer have discussed the approach. PRs that don't meet this requirement are automatically closed with a descriptive comment.
2. **Enforces draft status** — All PRs must start as drafts. Non-draft PRs are automatically converted and labeled.

Maintainers (users with `admin` or `maintain` role) are exempt from the issue reference validation. Draft enforcement applies to everyone.

## Usage

Create `.github/workflows/validate-pr.yml` in your repository:

```yaml
name: Validate PR

on:
  pull_request_target:
    types: [opened, reopened]

jobs:
  validate-pr:
    runs-on: ubuntu-24.04
    permissions:
      pull-requests: write
    steps:
      - uses: getsentry/github-workflows/validate-pr@v3
        with:
          app-id: ${{ vars.SDK_MAINTAINER_BOT_APP_ID }}
          private-key: ${{ secrets.SDK_MAINTAINER_BOT_PRIVATE_KEY }}
```

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `app-id` | Yes | GitHub App ID for the SDK Maintainer Bot |
| `private-key` | Yes | GitHub App private key for the SDK Maintainer Bot |

## Outputs

| Output | Description |
|--------|-------------|
| `was-closed` | `'true'` if the PR was closed by validation, unset otherwise |

## Validation rules

### Issue reference check

The PR body is scanned for issue references in these formats:

- `#123` (same-repo)
- `getsentry/repo#123` (cross-repo)
- `https://github.com/getsentry/repo/issues/123` (full URL)
- With optional keywords: `Fixes #123`, `Closes getsentry/repo#123`, etc.

A PR is valid if **any** referenced issue passes all checks:
- The issue is fetchable and in a `getsentry` repository
- If the issue has assignees, the PR author must be one of them
- Both the PR author and a maintainer have participated in the issue discussion

### Draft enforcement

Non-draft PRs are converted to draft and labeled `converted-to-draft` with an informational comment.

## Labels

The action creates these labels automatically (they don't need to exist beforehand):

- `violating-contribution-guidelines` — added to all closed PRs
- `missing-issue-reference` — PR body has no issue references
- `missing-maintainer-discussion` — referenced issue lacks author + maintainer discussion
- `issue-already-assigned` — referenced issue is assigned to someone else
- `converted-to-draft` — PR was automatically converted to draft
