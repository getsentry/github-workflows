# Workflows

This repository contains reusable workflows and scripts to be used with GitHub Actions.

For versioning, we're using a shifting tag strategy, with the current version tag - e.g. `v1` - being updated until
there's a breaking change, at which point a it will stay as is and we start using a new tag, `v2`, etc...

This allows consumers to be on the latest version of a compatible workflow. If you prefer, you can instead pin to a
specific commit.

## Contributing

Note on versioning: Reusable workflows don't support version selection based on the major version specified
by the user - instead, an exact ref is needed, that's why we have to shift the tag as needed.

To shift the tag to the current commit:

```shell-script
git push
git tag -d v1
git tag v1
git push --tags --force
```
