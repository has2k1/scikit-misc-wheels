#!/bin/bash

# Auto-deploy with Travis
# Credit: https://gist.github.com/domenic/ec8b0fc8ab45f39403dd
set -o xtrace  # Print command traces before executing command
set -e # Exit with nonzero exit code if anything fails

TOP_LEVEL=`git rev-parse --show-toplevel`
SOURCE_BRANCH="master"
TARGET_BRANCH="wheelhouse"
COMMIT_AUTHOR_NAME=$(git --no-pager show -s --format='%an')
COMMIT_AUTHOR_EMAIL=$(git --no-pager show -s --format='%ae')
ENCRYPTED_DEPLOY_KEY_FILE="$TRAVIS_BUILD_DIR/tools/deploy_key.enc"
DEPLOY_KEY_FILE="$TRAVIS_BUILD_DIR/tools/deploy_key"
# No of entries in the matrix.include section of .travis.yml
BUILD_MATRIX_SIZE=9
# Commits are assembled in the working directory
WORKING_DIR="/tmp/commit_wheel"
# where the build script put the wheel(s)
WHEELHOUSE_DIRECTORY="$TRAVIS_BUILD_DIR/wheelhouse"
TARGET_BRANCH_DIRECTORY="$WORKING_DIR/$TARGET_BRANCH"
BUILD_ID="$(date +%Y-%m-%d:%H:%M)--${BUILD_COMMIT}"
# where the wheels for this build will be committed
WHEEL_COMMIT_DIRECTORY="$TARGET_BRANCH_DIRECTORY/$BUILD_ID"

# Get the deploy key by using Travis's stored variables to decrypt deploy_key.enc
ENCRYPTED_KEY_VAR="encrypted_${ENCRYPTION_LABEL}_key"
ENCRYPTED_IV_VAR="encrypted_${ENCRYPTION_LABEL}_iv"
ENCRYPTED_KEY=${!ENCRYPTED_KEY_VAR}
ENCRYPTED_IV=${!ENCRYPTED_IV_VAR}

# Save some useful information
REPO=`git config remote.origin.url`
SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}

# Hack. When the builds compete to update the remote origin,
# some pushes may fail. In that case we pull-rebase and then
# try to push again.
function push_pull_rebase {
   N=$BUILD_MATRIX_SIZE
   PUSH_CMD="git push $SSH_REPO $TARGET_BRANCH"

   for i in {1..$N}; do
      # Command does not fail, script does not exit
      # yet we still get the error code. :)
      error_code=$(eval $PUSH_CMD || echo $?)
      if [[ $error_code -eq 0 ]]; then
         break
      elif [[ ! $i -eq $N ]]; then
         # One of the other parallel builds beat this
         # build to the update, so commit goes on top
         git pull --rebase=True origin/$TARGET_BRANCH
      else
         echo "$PUSH_CMD -- FAILED"
         exit 1
      fi
   done
}

openssl aes-256-cbc -K $ENCRYPTED_KEY -iv $ENCRYPTED_IV \
   -in $ENCRYPTED_DEPLOY_KEY_FILE -out $DEPLOY_KEY_FILE -d

chmod 600 $DEPLOY_KEY_FILE
eval `ssh-agent -s`
ssh-add $DEPLOY_KEY_FILE


mkdir $WORKING_DIR

# Clone the existing wheelhouse for this repo into out/
# Create a new empty branch if gh-pages doesn't exist
# yet (should only happen on first deply)
git clone --depth=3 --branch=$TARGET_BRANCH $SSH_REPO $TARGET_BRANCH_DIRECTORY || true
if [[ -d $TARGET_BRANCH_DIRECTORY ]]; then
   pushd $TARGET_BRANCH_DIRECTORY
else
   git clone -l -s -n . $TARGET_BRANCH_DIRECTORY
   pushd $TARGET_BRANCH_DIRECTORY
   git checkout $TARGET_BRANCH || git checkout --orphan $TARGET_BRANCH
   git reset --hard
fi

if [[ ! -d $WHEEL_COMMIT_DIRECTORY ]]; then
   mkdir $WHEEL_COMMIT_DIRECTORY
fi

# Copy the wheels
cp -a "$WHEELHOUSE_DIRECTORY/." "$WHEEL_COMMIT_DIRECTORY/"

# Now let's go have some fun with the cloned repo
git config user.name "$COMMIT_AUTHOR_NAME via Travis CI"
git config user.email "$COMMIT_AUTHOR_EMAIL"
git config --local -l

# Track and commit
git add "$WHEEL_COMMIT_DIRECTORY/"

# If there are no changes to the compiled out (e.g. this is a README update) then just bail.
if [ -z `git diff --cached --exit-code --shortstat` ]; then
    echo "No changes to the output on this push; exiting."
    exit 0
fi

git commit -m "$BUILD_ID"

push_pull_rebase

popd
rm -rf $WORKING_DIRECTORY
