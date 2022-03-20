#!/usr/bin/env bash
# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* .

# use pkg-config from BUILD_PREFIX
export PKG_CONFIG=$BUILD_PREFIX/bin/pkg-config

./configure --prefix="${PREFIX}" 
make -j${CPU_COUNT}
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR}" != "" ]]; then
if [[ "${target_platform}" != "linux-ppc64le" ]]; then
  make check || (cat test/test-suite.log && echo "ERROR: make check failed, see above" && exit 1)
fi
fi
make install
