#!/usr/bin/env bash
set -euo pipefail

# This script si run by `workflow-tests.yml` and it checks that the arguments passed to updater.yml are used properly.

case $1 in
get-version)
    # Return the actual latest tag to ensure no update is needed
    # Always use remote lookup for consistency with update-dependency.ps1
    tags=$(git ls-remote --tags --refs https://github.com/getsentry/github-workflows.git | \
           sed 's/.*refs\/tags\///' | \
           grep -E '^v?[0-9.]+$')

    # Sort by version number, handling mixed v prefixes
    latest=$(echo "$tags" | sed 's/^v//' | sort -V | tail -1)

    # Check if original had v prefix and restore it
    if echo "$tags" | grep -q "^v$latest$"; then
        echo "v$latest"
    else
        echo "$latest"
    fi

    # Run actual tests here.
    if [[ "$(uname)" != 'Darwin' ]]; then
        echo "This workflow should run macOS - expecting uname to return 'Darwin', but got '$(uname)'."
        exit 1
    fi
    ;;
get-repo)
    echo "https://github.com/getsentry/github-workflows.git"
    ;;
set-version)
    # This is unlikely to be called - only when a new version of github-workflows is pushed.
    # To update the version, we update the content of this script itself (in the `get-version` section above).
    content=$(cat $0)
    shopt -s extglob
    echo "${content/echo \"+([^\"])\"/echo \"$2\"}" >$0
    ;;
*)
    echo "Unknown argument $1"
    exit 1
    ;;
esac
