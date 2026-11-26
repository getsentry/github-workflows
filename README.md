# GitHub Workflows

This repository contains composite actions and scripts to be used with GitHub Actions.

## Composite Actions

### Updater

Dependency updater - updates dependencies to the latest published git tag and creates/updates PRs.

**[📖 View full documentation →](updater/README.md)**

### Danger

Runs DangerJS on Pull Requests with a pre-configured set of rules.

**[📖 View full documentation →](danger/README.md)**

### Skip CI

Tells whether a push to a pull request only changes files that need no CI, such as Markdown, so expensive jobs can be skipped.

**[📖 View full documentation →](skip-ci/README.md)**

### PR Classifiers

Classifies a pull request with the internal classifiers action and labels it, without checking out or running the pull request's code.

**[📖 View full documentation →](pr-classifiers/README.md)**

## Legacy Reusable Workflows (v2)

> ⚠️ **Deprecated**: Reusable workflows have been converted to composite actions in v3. Please migrate to the composite actions above.

For v2 migration guide and breaking changes, see [CHANGELOG.md](CHANGELOG.md#3.0.0).
