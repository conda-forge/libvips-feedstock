 #!/usr/bin/env bash
set -ex

# Keep in sync with `meson_config_args` in `bld.bat`.
meson_config_args=(
    -Dauto_features=enabled
    -Dcgif=enabled
    -Dimagequant=enabled
    -Dmatio=disabled
    -Dnifti=disabled
    -Dopenexr=disabled
    -Dpdfium=disabled
    -Dquantizr=disabled
    -Duhdr=enabled
    -Dintrospection=disabled
)

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
