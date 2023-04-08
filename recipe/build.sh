 #!/usr/bin/env bash
set -ex

if [ "${CONDA_BUILD_CROSS_COMPILATION}" = "1" ]; then
    unset _CONDA_PYTHON_SYSCONFIGDATA_NAME
    (
        mkdir -p native-build

        export CC=$CC_FOR_BUILD
        export CXX=$CXX_FOR_BUILD
        export AR=$($CC_FOR_BUILD -print-prog-name=ar)
        export NM=$($CC_FOR_BUILD -print-prog-name=nm)
        export LDFLAGS=${LDFLAGS//$PREFIX/$BUILD_PREFIX}
        export PKG_CONFIG_PATH=${BUILD_PREFIX}/lib/pkgconfig

        # Unset them as we're ok with builds that are either slow or non-portable
        unset CFLAGS
        unset CPPFLAGS
        unset CXXFLAGS

        meson setup native-build --prefix="${BUILD_PREFIX}" -Dlibdir=lib
        # This script would generate the functions.txt and dump.xml and save them
        # This is loaded in the native build. We assume that the functions exported
        # by glib are the same for the native and cross builds
        export GI_CROSS_LAUNCHER=$BUILD_PREFIX/libexec/gi-cross-launcher-save.sh
        ninja -C native-build -j ${CPU_COUNT}
        ninja -C native-build install -j ${CPU_COUNT}
    )

    export GI_CROSS_LAUNCHER=$BUILD_PREFIX/libexec/gi-cross-launcher-load.sh
fi

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
   # We need the full gojbect-introspection to be installed in
   # the host environment, but we want to use the build executables
   # meson will look for this file as a dependency, but we want it to use
   # the build tools, not the host ones
   # https://github.com/conda-forge/gobject-introspection-feedstock/issues/64
   # g-ir-scanner has a few hardcoded constants that we need to use the
   # the build version for during cross compilation
   # https://gitlab.gnome.org/GNOME/gobject-introspection/-/blob/main/tools/g-ir-tool-template.in#L58
   # rm -f ${PREFIX}/bin/g-ir-scanner
   # ln -s ${BUILD_PREFIX}/bin/g-ir-scanner ${PREFIX}/bin/g-ir-scanner

   # Without removing giscanner from lib, it seems to find from the host on OSX
   # rm -rf ${PREFIX}/lib/gobject-introspection/giscanner/

   # Is there a better way to use ldd for cross compilation??
   if [[ "${target_platform}" == linux-* ]]; then
       # https://github.com/conda-forge/ctng-compilers-feedstock/issues/110

       # Is there a better way to specify a cross compilation ldd
       # gobject-introspection knows that this is hard.
       # they either suggest passing in an ldd wrapper, or ensuring that
       # the path is setup such that the first ldd found is the optimal one
       # We choose the second strategy
       cp ${CONDA_BUILD_SYSROOT}/usr/bin/ldd ${BUILD_PREFIX}/bin/ldd

       # On ppc64le it is specified as two things, so we have to augment both
       sed -i "/^RTLDLIST/s,/lib/,${CONDA_BUILD_SYSROOT}/lib/," ${BUILD_PREFIX}/bin/ldd
       sed -i "/^RTLDLIST/s,/lib64/,${CONDA_BUILD_SYSROOT}/lib64/," ${BUILD_PREFIX}/bin/ldd
   fi
fi

# Allow pkg-config to find gobject-introspection from the build tools
# https://gitlab.gnome.org/GNOME/gobject-introspection/-/issues/462
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$BUILD_PREFIX/lib/pkgconfig"

meson setup build ${MESON_ARGS} --prefix="${PREFIX}" -Dlibdir=lib

meson compile -C build -j ${CPU_COUNT}

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR}" != "" ]]; then
if [[ "${target_platform}" != "linux-ppc64le" ]]; then
  meson test -C build --timeout-multiplier 0
fi
fi

meson install -C build
