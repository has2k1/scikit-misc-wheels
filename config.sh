# Define custom utilities
# Test for OSX with [ -n "$IS_OSX" ]
# See env_vars.sh for extra environment variables
source gfortran-install/gfortran_utils.sh

# From https://github.com/MacPython/scipy-wheels
function build_wheel {
    if [ -z "$IS_OSX" ]; then
        unset FFLAGS
        export LDFLAGS="-shared -Wl,-strip-all"
        build_libs $PLAT
        # build_pip_wheel does not work with versioneer
        # https://github.com/matthew-brett/multibuild/issues/11
        build_pip_wheel $@
    else
        export FFLAGS="$FFLAGS -fPIC"
        build_osx_wheel $@
    fi
}

# From https://github.com/MacPython/scipy-wheels
function build_libs {
    PYTHON_EXE=`which python`
    $PYTHON_EXE -c"import platform; print('platform.uname().machine', platform.uname().machine)"
    basedir=$($PYTHON_EXE openblas_support.py)
    $use_sudo cp -r $basedir/lib/* /usr/local/lib
    $use_sudo cp $basedir/include/* /usr/local/include
}

# used by build_osx_wheel
function set_arch {
    local arch=$1
    export CC="clang $arch"
    export CXX="clang++ $arch"
    export CFLAGS="$arch"
    export FFLAGS="$arch"
    export FARCH="$arch"
    export LDFLAGS="$arch"
}

# From https://github.com/MacPython/scipy-wheels
function build_wheel_with_patch {
    # Patch numpy distutils to fix OpenBLAS build
    (cd .. && ./patch_numpy.sh)
    bdist_wheel_cmd $@
}

# From https://github.com/MacPython/scipy-wheels
function build_osx_wheel {
    # Build 64-bit wheel
    # Standard gfortran won't build dual arch objects.
    local repo_dir=${1:-$REPO_DIR}
    local py_ld_flags="-Wall -undefined dynamic_lookup -bundle"

    install_gfortran
    # 64-bit wheel
    local arch="-m64"
    set_arch $arch
    build_libs x86_64
    # Build wheel
    export LDSHARED="$CC $py_ld_flags"
    export LDFLAGS="$arch $py_ld_flags"
    # Work round build dependencies spec in pyproject.toml
    # See e.g.
    # https://travis-ci.org/matthew-brett/scipy-wheels/jobs/387794282
    build_bdist_wheel "$repo_dir"
    # build_wheel_cmd "build_wheel_with_patch" "$repo_dir"
}

function run_tests {
    # Runs tests on installed distribution from an empty directory
    python --version
    pip list
    test_cmd="import sys, skmisc; sys.exit(skmisc.test())"

    if [[ -n "$IS_OSX" && `uname -m` != 'aarch64' ]]; then
        arch -x86_64 python -c "$test_cmd"
    else
        python -c "$test_cmd"
    fi

    python -c "import skmisc; skmisc.show_config()"
}
