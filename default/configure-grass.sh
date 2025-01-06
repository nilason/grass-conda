#!/bin/bash

############################################################################
#
# TOOL:         configure-grass.sh
# AUTHOR(s):    Nicklas Larsson
# PURPOSE:      Sets up configure and compiler flags and configures GRASS GIS
# COPYRIGHT:    (c) 2020-2025 Nicklas Larsson
#               This package is free software under the GNU General Public
#               License (>=v2).
#
#############################################################################
#
#
#

export PREFIX=$(python3 -c 'import sys; print(sys.prefix)')
export PATH=$PREFIX/bin:/usr/bin:/bin:/usr/sbin:/etc:/usr/lib
export GRASS_PYTHON=$(which pythonw)
export CC=$PREFIX/bin/clang
export CXX=$PREFIX/bin/clang++
export MACOSX_DEPLOYMENT_TARGET=$DEPLOYMENT_TARGET
export CONDA_BUILD_SYSROOT=$BUILD_SDK

if [ "$GRASS_VERSION_MAJOR$GRASS_VERSION_MINOR" -ge 79 ]; then
  export LDFLAGS="-fuse-ld=lld -Wl,-rpath,$PREFIX/lib"
  export CFLAGS="-O2 -pipe -arch ${CONDA_ARCH} -DGL_SILENCE_DEPRECATION"
  export CXXFLAGS="-O2 -pipe -stdlib=libc++ -arch ${CONDA_ARCH}"
fi

CONFIGURE_FLAGS="\
  --with-macosx-sdk=$CONDA_BUILD_SYSROOT \
  --with-opengl=aqua \
  --with-openmp \
  --prefix=$PREFIX \
  --without-x \
  --with-freetype \
  --with-freetype-includes=$PREFIX/include/freetype2 \
  --with-freetype-libs=$PREFIX/lib \
  --with-gdal=$PREFIX/bin/gdal-config \
  --with-proj-includes=$PREFIX/include \
  --with-proj-libs=$PREFIX/lib \
  --with-proj-share=$PREFIX/share/proj \
  --with-geos=$PREFIX/bin/geos-config \
  --with-libpng=$PREFIX/bin/libpng-config \
  --with-tiff-includes=$PREFIX/include \
  --with-tiff-libs=$PREFIX/lib \
  --with-postgres=yes \
  --with-postgres-includes=$PREFIX/include \
  --with-postgres-libs=$PREFIX/lib \
  --without-mysql \
  --with-sqlite \
  --with-sqlite-libs=$PREFIX/lib \
  --with-sqlite-includes=$PREFIX/include \
  --with-fftw-includes=$PREFIX/include \
  --with-fftw-libs=$PREFIX/lib \
  --with-cxx \
  --with-cairo \
  --with-cairo-includes=$PREFIX/include/cairo \
  --with-cairo-libs=$PREFIX/lib \
  --with-cairo-ldflags="-lcairo" \
  --with-zstd \
  --with-zstd-libs=$PREFIX/lib \
  --with-zstd-includes=$PREFIX/include \
  --with-bzlib \
  --with-bzlib-libs=$PREFIX/lib \
  --with-bzlib-includes=$PREFIX/include \
  --with-netcdf=$PREFIX/bin/nc-config \
  --with-netcdf=$PREFIX/bin/nc-config \
  --with-nls \
  --with-libsvm \
  --with-libs=$PREFIX/lib \
  --with-includes=$PREFIX/include \
  --with-pdal=$PREFIX/bin/pdal-config \
  --with-readline \
  --with-readline-includes=$PREFIX/include/readline \
  --with-readline-libs=$PREFIX/lib
"

if [ "$GRASS_VERSION_MAJOR$GRASS_VERSION_MINOR" -ge 85 ]; then
  CONFIGURE_FLAGS="\
      ${CONFIGURE_FLAGS} \
      --with-blas=openblas \
      --with-lapack=openblas
  "
else
  CONFIGURE_FLAGS="\
      ${CONFIGURE_FLAGS} \
        --with-blas \
        --with-blas-libs=$PREFIX/lib \
        --with-blas-includes=$PREFIX/include \
        --with-lapack \
        --with-lapack-includes=$PREFIX/include \
        --with-lapack-libs=$PREFIX/lib
  "
fi

if [[ "$WITH_LIBLAS" -eq 1 ]]; then
    CONFIGURE_FLAGS="\
        ${CONFIGURE_FLAGS} \
        --with-liblas=$PREFIX/bin/liblas-config
    "
fi

./configure $CONFIGURE_FLAGS
