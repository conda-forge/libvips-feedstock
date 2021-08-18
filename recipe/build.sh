#!/usr/bin/env bash
# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* .

./configure --prefix="${PREFIX}" 
make -j${CPU_COUNT}
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" ]]; then
make check || (cat test/test-suite.log && echo "ERROR: make check failed, see above" && exit 1)
fi
make install
