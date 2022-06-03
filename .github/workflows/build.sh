#!/bin/bash
# Ref: https://github.com/python-pillow/pillow-wheels/blob/44625090507e1/.github/workflows/build.sh
# Changes:
# 1. Removed code related to pypy-osx interaction

BUILD_DEPENDS="$NP_BUILD_DEP $CYTHON_BUILD_DEP $PYBIND11_BUILD_DEP"
TEST_DEPENDS="$NP_TEST_DEP $OTHER_TEST_DEPS"
SKIP_TESTS=false
UNAME=$(uname)
NATIVE_PLAT=$(uname -m)
BUILD_COMMIT_FILE="${BUILD_DIR}/.github/workflows/build_commit.sh"

# When crosspiling we cannot install the built wheel, we trust
# that it works!
if [[ "$PLAT" != "$NATIVE_PLAT" ]]; then
  if [[ "$PLAT" != "universal2" ]]; then
    SKIP_TESTS=true
  fi
fi

if [[ "$UNAME" == "Linux" ]]; then
  # https://github.com/multi-build/multibuild/issues/470
  ! git config --global --add safe.directory "*"
fi

if [ -r "$BUILD_COMMIT_FILE" ]; then source "$BUILD_COMMIT_FILE"; fi

echo "::group::Install a virtualenv"
  source multibuild/common_utils.sh
  source multibuild/travis_steps.sh
  pip install virtualenv
  before_install
echo "::endgroup::"

echo "::group::Build wheel"
  clean_code $REPO_DIR $BUILD_COMMIT
  build_wheel $REPO_DIR $PLAT
  ls -l "${GITHUB_WORKSPACE}/${WHEEL_SDIR}/"
echo "::endgroup::"

if [[ "$SKIP_TESTS" == false ]]; then
  echo "::group::Test wheel"
    install_run $PLAT
  echo "::endgroup::"
fi
