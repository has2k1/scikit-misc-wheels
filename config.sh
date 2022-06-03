# Define custom utilities
# Test for OSX with [ -n "$IS_OSX" ]
# See env_vars.sh for extra environment variables
source gfortran-install/gfortran_utils.sh

# From https://github.com/MacPython/scipy-wheels
function build_wheel {
    export FFLAGS="$FFLAGS -fPIC"
    if [ -z "$IS_OSX" ]; then
        build_libs $PLAT
        # Work round build dependencies spec in pyproject.toml
        build_bdist_wheel $@
    else
        # Ref: https://github.com/scipy/scipy/issues/14829
        # solution: https://github.com/scipy/scipy/pull/14831/files
        export LIBRARY_PATH="$LIBRARY_PATH:/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib"
        install_gfortran
        wrap_wheel_builder build_osx_wheel $@
    fi
}

# From https://github.com/MacPython/scipy-wheels
function build_libs {
    PYTHON_EXE=`which python`
    $PYTHON_EXE -c"import platform; print('platform.uname().machine', platform.uname().machine)"
    basedir=$($PYTHON_EXE openblas_support.py)
    $use_sudo cp -r $basedir/lib/* $BUILD_PREFIX/lib
    $use_sudo cp $basedir/include/* $BUILD_PREFIX/include
    export OPENBLAS=$BUILD_PREFIX
}

# From https://github.com/MacPython/scipy-wheels
function build_wheel_with_patch {
    # Patch numpy distutils to fix OpenBLAS build
    (cd .. && ./patch_numpy.sh)
    bdist_wheel_cmd $@
}

# From https://github.com/MacPython/scipy-wheels
function build_osx_wheel {
    local repo_dir=${1:-$REPO_DIR}
    if [ ! -z "$FC" ]; then
       export F77=$FC
       export F90=$FC
    fi
    build_libs
    # Work round build dependencies spec in pyproject.toml
    # See e.g.
    # https://travis-ci.org/matthew-brett/scipy-wheels/jobs/387794282
    build_bdist_wheel "$repo_dir"
}

function run_tests {
    # Runs tests on installed distribution from an empty directory
    python --version
    pip list
    test_cmd="import sys, skmisc; sys.exit(skmisc.test())"
    python -c "$test_cmd"
    python -c "import skmisc; skmisc.show_config()"
}
