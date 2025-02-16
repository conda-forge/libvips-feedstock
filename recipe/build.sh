 #!/usr/bin/env bash
set -ex

# Stopgap while https://github.com/conda-forge/libiconv-feedstock/pull/46
# it will have a similar file generated
iconv_pc_created=false
if [[ ! -z "${libiconv}" ]] && [[ ! -f ${PREFIX}/lib/pkgconfig/iconv.pc ]]; then
    iconv_pc_created=true
    echo >${PREFIX}/lib/pkgconfig/iconv.pc <<EOF
prefix=${PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include
Name: iconv
Description: GNU Unicode conversion library
Version: ${libiconv}
Libs: -L\${libdir} -liconv
Cflags: -I\${includedir}
EOF
fi


pkg-config --exists --debug libarchive

meson_config_args=(
    -Dintrospection=enabled
    -Dopenslide=enabled
)

if [ "${CONDA_BUILD_CROSS_COMPILATION}" = "1" ]; then
    if [[ ! -z "${libiconv}" ]] && [[ ! -f ${PREFIX}/lib/pkgconfig/iconv.pc ]]; then
        echo >${BUILD_PREFIX}/lib/pkgconfig/iconv.pc <<EOF
prefix=${BUILD_PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include
Name: iconv
Description: GNU Unicode conversion library
Version: ${libiconv}
Libs: -L\${libdir} -liconv
Cflags: -I\${includedir}
EOF
    fi

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

        meson setup native-build \
            "${meson_config_args[@]}" \
            --buildtype=release \
            --prefix=${BUILD_PREFIX} \
            -Dlibdir=lib

        # This script would generate the functions.txt and dump.xml and save them
        # This is loaded in the native build. We assume that the functions exported
        # by the package are the same for the native and cross builds
        export GI_CROSS_LAUNCHER=$BUILD_PREFIX/libexec/gi-cross-launcher-save.sh
        ninja -C native-build -j ${CPU_COUNT}
        ninja -C native-build install -j ${CPU_COUNT}
    )

    export GI_CROSS_LAUNCHER=$BUILD_PREFIX/libexec/gi-cross-launcher-load.sh
fi

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" && "${target_platform}" == linux-* ]]; then
    # Is there a better way to use ldd during cross compilation?
    # gobject-introspection either suggests passing an ldd wrapper, or ensuring
    # that the native ldd can be used. We choose the second strategy.
    # https://github.com/conda-forge/ctng-compilers-feedstock/issues/110
    cp ${CONDA_BUILD_SYSROOT}/usr/bin/ldd ${BUILD_PREFIX}/bin/ldd

    # On ppc64le it is specified as two things, so we have to argument both
    sed -i "/^RTLDLIST/s,/lib/,${CONDA_BUILD_SYSROOT}/lib/," ${BUILD_PREFIX}/bin/ldd
    sed -i "/^RTLDLIST/s,/lib64/,${CONDA_BUILD_SYSROOT}/lib64/," ${BUILD_PREFIX}/bin/ldd
fi

# Allow pkg-config to find gobject-introspection from the build tools
# https://gitlab.gnome.org/GNOME/gobject-introspection/-/issues/462
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$BUILD_PREFIX/lib/pkgconfig

meson setup build \
    ${MESON_ARGS} \
    "${meson_config_args[@]}" \
    --prefix=${PREFIX} \
    -Dlibdir=lib
meson compile -C build -j ${CPU_COUNT}

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR}" != "" ]]; then
    # Increase the test timeout when running under emulation
    meson test -C build ${CROSSCOMPILING_EMULATOR:+--timeout-multiplier=16}
fi

meson install -C build

if [[ "${iconv_pc_created}" == "true" ]]; then
    rm -f ${PREFIX}/lib/pkgconfig/iconv.pc
fi
