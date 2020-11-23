#!/bin/bash

# Auto-deploy with Github Actions
# Credit: https://gist.github.com/domenic/ec8b0fc8ab45f39403dd
set -o xtrace  # Print command traces before executing command
set -e         # Exit with nonzero exit code if anything fails
echo $BASH_VERSION  # For debugging

# Notes
# 1. Expects enviroment variables
#    WHEELHOUSE_DIR - Full path to the directory with the built wheels
#    WHEELS_BRANCH - Branch in which the wheels are stored
#
# 2. Directory structure of the wheelhouse branch is
#    - README.md
#    - v0.1.1
#         - scikit-misc-0.1.1-*.whl
#    - v0.1.3
#         - scikit-misc-0.1.3-*.whl
#    - v0.2.0
#         - scikit-misc-0.2.0-*.whl
#    The wheels are placed in directories whose name is the version of
#    the wheel.

# Setup variables
COMMIT_AUTHOR_NAME="Github Actions"
COMMIT_AUTHOR_EMAIL="github-actions@github.com"
a_wheel_filename=$(ls -1 $WHEELHOUSE_DIR | head -n 1)
WHEEL_VERSION=$(echo $a_wheel_filename | cut -d '-' -f 2)  # Extract version from name
WHEEL_COMMIT_DIR="${WHEEL_VERSION}"  # where the wheels for the build will be committed
COMMIT_MSG="${WHEEL_VERSION} ($(date +%Y-%m-%d:%H:%M:%S))"

# Create directory for this version and copy wheels into it
mkdir -p "$WHEEL_COMMIT_DIR"
cp -a "$WHEELHOUSE_DIR/." "$WHEEL_COMMIT_DIR/"

# Fetch
git fetch origin "$WHEELS_BRANCH"
git checkout "$WHEELS_BRANCH"

# Configure commit information
git config user.name "$COMMIT_AUTHOR_NAME  [GA Commit Wheel]"
git config user.email "$COMMIT_AUTHOR_EMAIL"

# Add and commit if they are changes
git add "$WHEEL_COMMIT_DIR"
if [[ -z `git diff --cached --exit-code --shortstat` ]]; then
    echo "No changes to the output on this push; exiting."
    exit 0
fi
git commit -m "$COMMIT_MSG"
git push
