# PR Classifiers

Classifies a pull request with the internal [getsentry/classifiers](https://github.com/getsentry/classifiers) action and puts the result on the pull request. Today there is one classifier, risk, which adds one of the labels `risk: low`, `risk: medium` or `risk: high`.

This action wraps the steps every repository used to copy: getting a token for the internal repository, checking it out at a pinned commit, running its action and uploading the result. The label is a hint for reviewers, not an approval to merge.

## Usage

Create `.github/workflows/pr-classifiers.yml` in your repository:

```yaml
name: PR classifiers

on:
  pull_request_target:
    # Keep `edited`: it is the only event fired when the base branch changes.
    types: [opened, synchronize, reopened, ready_for_review, edited, converted_to_draft]

permissions: {}

concurrency:
  # Two groups per pull request; do not simplify this expression. See "Concurrency" below.
  group: pr-classifiers-${{ github.event.pull_request.number }}-${{ github.event.action == 'edited' && !github.event.changes.base && 'text' || 'score' }}
  cancel-in-progress: false

jobs:
  classify:
    name: PR classifiers
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: getsentry/github-workflows/pr-classifiers@<sha>
        with:
          app-client-id: ${{ vars.CLASSIFIERS_APP_CLIENT_ID }}
          app-private-key: ${{ secrets.CLASSIFIERS_APP_KEY }}
          ai-gateway-api-key: ${{ secrets.AI_GATEWAY_API_KEY }}
```

Pin to a specific commit SHA, never a branch or tag: the job holds secrets on pull requests from forks.

The repository also needs a fact sheet at `.github/classifiers.toml` on its default branch. It tells the classifier which paths ship, where that code runs, and which are tests, docs or build configuration. The format is described in the [classifiers documentation](https://github.com/getsentry/classifiers/blob/main/classifiers/pr/risk/README.md#fact-sheets). A repository without a fact sheet is not classified, and the job stays green.

## Rules for the calling workflow

A composite action cannot set a workflow's trigger, permissions or concurrency, so these stay in your workflow file:

- **Never check out or run code from the pull request in this job.** The workflow runs on `pull_request_target` and holds secrets. The classifier reads the pull request's commits itself and executes none of them.
- **Permissions.** `permissions: {}` at the top; `contents: read` and `pull-requests: write` on the one job. `pull-requests: write` is only needed for `publish-label` and `publish-comment`.
- **No `workflow_dispatch`** if the result will gate anything: a manual run has no head commit to check against.
- **No condition on drafts.** Drafts are scored.

### Concurrency

Keep the `concurrency` block exactly as in the example. It puts runs started by a title or description edit in a different group from the runs that score a commit. GitHub keeps only one pending run per group, so in one shared group a pending edit run would replace the pending run for a new commit and then be skipped, leaving the previous commit's label on the new commit. `cancel-in-progress: false` lets every started run reach its label clear.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `app-client-id` | Yes | | Client ID of the GitHub App that can read `getsentry/classifiers` (the client ID, not the numeric App ID) |
| `app-private-key` | Yes | | Private key of that GitHub App |
| `ai-gateway-api-key` | Yes | | AI Gateway key for the model call. Use a dedicated key with a spend cap: anyone can start runs by opening a pull request |
| `classifiers-ref` | No | pinned commit | Commit of `getsentry/classifiers` to run |
| `publish-label` | No | `true` | `true` lets the action own the three risk labels |
| `publish-comment` | No | `false` | `true` keeps one summary comment on the pull request |
| `upload-result` | No | `true` | `true` uploads the public result JSON as the artifact `pr-classifiers-<number>` |

The fact sheet is read from the pull request's base commit, so a pull request that changes the sheet is scored with the sheet already merged, and such a pull request is never `low`.

## Outputs

| Output | Description |
|--------|-------------|
| `status` | How the run ended; `ok` when the pull request was classified |
| `risk-label` | The final label, or empty when the status is not `ok` |
| `model-label` | The model's label before the rules that block low |
| `head-sha`, `base-sha` | The commits that were scored |
| `label-published` | `true` only when the risk label was added to the unchanged pull request |
| `summary` | Markdown summary of the result |

`summary` holds text derived from the pull request, such as file paths. Pass it through an environment variable and never put `${{ }}` inside a `run:` script.

The statuses, what a run publishes, and what a workflow must check before acting on a `low` are documented in the [classifiers README](https://github.com/getsentry/classifiers#statuses).
