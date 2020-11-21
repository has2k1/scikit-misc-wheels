#!/bin/bash
# Ref: https://github.com/python-pillow/pillow-wheels/blob/44625090507e1/.github/workflows/build.sh
# Changes:
# 1. Removed code related to pypy-osx interaction

BUILD_DEPENDS="$NP_BUILD_DEP $CYTHON_BUILD_DEP $PYBIND11_BUILD_DEP"
TEST_DEPENDS="$NP_TEST_DEP $OTHER_TEST_DEPS"

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

echo "::group::Test wheel"
  install_run $PLAT
echo "::endgroup::"
