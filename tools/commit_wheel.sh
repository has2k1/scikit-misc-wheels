#!/bin/bash

# Auto-deploy with Github Actions
# Credit: https://gist.github.com/domenic/ec8b0fc8ab45f39403dd
set -o xtrace  # Print command traces before executing command
set -e # Exit with nonzero exit code if anything fails
echo $BASH_VERSION  # For debugging

TARGET_BRANCH="wheelhouse"
COMMIT_AUTHOR_NAME=$(git --no-pager show -s --format='%an')
COMMIT_AUTHOR_EMAIL=$(git --no-pager show -s --format='%ae')
ENCRYPTED_DEPLOY_KEY_FILE="$BUILD_DIR/tools/deploy_key.enc"
DEPLOY_KEY_FILE="$BUILD_DIR/tools/deploy_key"
# Commits are assembled in the working directory
WORKING_DIR="/tmp/commit_wheel"
# where the build script put the wheel(s)
WHEELHOUSE_DIRECTORY="$BUILD_DIR/wheelhouse"
LOCAL_REPO="$WORKING_DIR/$TARGET_BRANCH"

# Process the filename of the wheel to get the version
# For the filename convention, see PEP 427
wheel_filename=$(ls -1 $WHEELHOUSE_DIRECTORY | head -n 1)
WHEEL_VERSION=$(echo $wheel_filename | cut -d '-' -f 2)

# where the wheels for this build will be committed
WHEEL_COMMIT_DIRECTORY=$WHEEL_VERSION
COMMIT_MSG="${WHEEL_VERSION} ($(date +%Y-%m-%d:%H:%M:%S))"

# Save some useful information
REPO=`git config remote.origin.url`
SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}

eval `ssh-agent -s`
echo "$GHA_DEPLOY_KEY" | ssh-add -
mkdir -p ~/.ssh/
ssh-keyscan github.com >> ~/.ssh/known_hosts

mkdir $WORKING_DIR

# Clone the existing wheelhouse for this repo into out/
# Create a new empty branch if gh-pages doesn't exist
# yet (should only happen on first deply)
git clone --depth=2 --branch=$TARGET_BRANCH $SSH_REPO $LOCAL_REPO || true
if [[ -d $LOCAL_REPO ]]; then
   pushd $LOCAL_REPO
else
   git clone -l -s -n . $LOCAL_REPO
   pushd $LOCAL_REPO
   # We cloned a local repository, but the wheels will be
   # pushed to a new branch in the remote repository.
   # That remote (SSH_REPO) should be the origin.
   git remote remove origin
   git remote add origin $SSH_REPO
   git checkout $TARGET_BRANCH || git checkout --orphan $TARGET_BRANCH
   git reset --hard
fi

if [[ ! -d $WHEEL_COMMIT_DIRECTORY ]]; then
   mkdir $WHEEL_COMMIT_DIRECTORY
fi

# Copy the wheels
cp -a "$WHEELHOUSE_DIRECTORY/." "$WHEEL_COMMIT_DIRECTORY/"

# Now let's go have some fun with the cloned repo
git config user.name "$COMMIT_AUTHOR_NAME  [GA Commit Wheel]"
git config user.email "$COMMIT_AUTHOR_EMAIL"
git config --local -l

# Track and commit
git add "$WHEEL_COMMIT_DIRECTORY/"

# If there are no changes to the compiled out (e.g. this is a README update) then just bail.
if [ -z `git diff --cached --exit-code --shortstat` ]; then
    echo "No changes to the output on this push; exiting."
    exit 0
fi

git commit -m "$COMMIT_MSG"
git pull --rebase=true origin $TARGET_BRANCH

git push origin "$TARGET_BRANCH:$TARGET_BRANCH"
ssh-agent -k

popd
rm -rf $WORKING_DIRECTORY
