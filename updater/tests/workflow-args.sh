#!/usr/bin/env bash
set -euo pipefail

# This script si run by `workflow-tests.yml` and it checks that the arguments passed to updater.yml are used properly.

case $1 in
get-version)
    echo "v3"

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
