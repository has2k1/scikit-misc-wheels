# Define custom utilities
# Test for OSX with [ -n "$IS_OSX" ]

OPENBLAS_VERSION=0.2.18
source gfortran-install/gfortran_utils.sh

function pre_build {
    # Any stuff that you need to do before you start building the wheels
    # Runs in the root directory of this repository.
    :
}

# From https://github.com/MacPython/scipy-wheels
function build_wheel {
    if [ -z "$IS_OSX" ]; then
        build_libs $PLAT
        # build_pip_wheel does not work with versioneer
        # https://github.com/matthew-brett/multibuild/issues/11
        build_pip_wheel $@
    else
        build_osx_wheel $@
    fi
}

# From https://github.com/MacPython/scipy-wheels
function build_libs {
    if [ -n "$IS_OSX" ]; then return; fi  # No OpenBLAS for OSX
    local plat=${1:-$PLAT}
    local tar_path=$(abspath $(get_gf_lib "openblas-${OPENBLAS_VERSION}" "$plat"))
    (cd / && tar zxf $tar_path)
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
function build_osx_wheel {
    # Build dual arch wheel
    # Standard gfortran won't build dual arch objects, so we have to build two
    # wheels, one for 32-bit, one for 64, then fuse them.
    local repo_dir=${1:-$REPO_DIR}
    local wheelhouse=$(abspath ${WHEEL_SDIR:-wheelhouse})
    local py_ld_flags="-Wall -undefined dynamic_lookup -bundle"
    local wheelhouse32=${wheelhouse}32

    install_gfortran

    # 32-bit wheel
    local arch="-m32"
    set_arch $arch
    # Build libraries
    build_libs i686
    # Build wheel
    mkdir -p $wheelhouse32
    export LDSHARED="$CC $py_ld_flags"
    export LDFLAGS="$arch $py_ld_flags"
    build_pip_wheel "$repo_dir"
    mv ${wheelhouse}/*whl $wheelhouse32

    # 64-bit wheel
    local arch="-m64"
    set_arch $arch
    build_libs x86_64
    # Build wheel
    export LDSHARED="$CC $py_ld_flags"
    export LDFLAGS="$arch $py_ld_flags"
    build_pip_wheel "$repo_dir"

    # Fuse into dual arch wheel(s)
    for whl in ${wheelhouse}/*.whl; do
        delocate-fuse "$whl" "${wheelhouse32}/$(basename $whl)"
    done
}

function run_tests {
    # Runs tests on installed distribution from an empty directory
    python --version
    pip list
    test_cmd="import sys, skmisc; sys.exit(skmisc.test())"

    if [ -n "$IS_OSX" ]; then
        # Test both architectures on OSX
        arch -i386 python -c "$test_cmd"
        arch -x86_64 python -c "$test_cmd"
    else
        python -c "$test_cmd"
    fi

    python -c "import skmisc; skmisc.show_config()"
}
