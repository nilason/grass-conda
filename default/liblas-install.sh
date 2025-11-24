#!/bin/bash

############################################################################
#
# TOOL:         liblas-install.sh
# AUTHOR(s):    Nicklas Larsson
# PURPOSE:      Downloads, compiles and installs libLAS.
# COPYRIGHT:    (c) 2021 Nicklas Larsson
#               This package is free software under the GNU General Public
#               License (>=v2).
#
#############################################################################
#
#
#

liblas_commit="0756b73ed41211d1bb8d9b96c6767f2350d8fe2b"
liblas_zipfile_name="libLAS_${liblas_commit}.zip"
liblas_zipfile_url="https://github.com/libLAS/libLAS/archive/${liblas_commit}.zip"
liblas_source_dir_name=libLAS-${liblas_commit}
liblas_build_dir_name=libLAS-build

liblas_zipfile="${EXTERNAL_DIR}/${liblas_zipfile_name}"
liblas_source_dir="${EXTERNAL_DIR}/${liblas_source_dir_name}"
liblas_build_dir="${EXTERNAL_DIR}/${liblas_build_dir_name}"

export PREFIX=$(python3 -c 'import sys; print(sys.prefix)')
export PATH=$PREFIX/bin:/usr/bin:/bin:/usr/sbin:/etc:/usr/lib
export CC=$PREFIX/bin/clang
export CXX=$PREFIX/bin/clang++
export MACOSX_DEPLOYMENT_TARGET=$DEPLOYMENT_TARGET
export CONDA_BUILD_SYSROOT=$BUILD_SDK
export CFLAGS="-O2 -pipe -arch ${CONDA_ARCH}"
export CXXFLAGS="-O2 -pipe -arch ${CONDA_ARCH} -stdlib=libc++"
export LDFLAGS="-fuse-ld=lld"
CMAKE=$PREFIX/bin/cmake

if [ ! -f "$liblas_zipfile" ]; then
    echo "Downloading libLAS..."
    curl -L "$liblas_zipfile_url" --output "${liblas_zipfile}"
    [ $? -ne 0 ] && exit 1
fi

rm -rf "$liblas_source_dir"
rm -rf "$liblas_build_dir"
mkdir -p "$liblas_source_dir"
mkdir -p "$liblas_build_dir"

unzip "$liblas_zipfile" -d "$EXTERNAL_DIR" &> /dev/null

# patch needed for using now outdated GDAL api
patch -d "$liblas_source_dir" -p0 << EOF
--- CMakeLists.txt.orig
+++ CMakeLists.txt
@@ -231,7 +231,7 @@
   endif ()
 endif ()
 if (GDAL_FOUND)
-  SET(CMAKE_CXX_STANDARD 11)
+  SET(CMAKE_CXX_STANDARD 14)
   SET(CMAKE_CXX_STANDARD_REQUIRED ON)
   SET(CMAKE_CXX_EXTENSIONS OFF)
   include_directories(${GDAL_INCLUDE_DIR})

EOF

LIBLAS_CONFIGURE_FLAGS="
  -DCMAKE_OSX_SYSROOT=${CONDA_BUILD_SYSROOT} \
  -DCMAKE_INCLUDE_PATH=${PREFIX}/include \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_MACOSX_RPATH=ON \
  -DCMAKE_INSTALL_RPATH=${PREFIX} \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_CXX_STANDARD=14 \
  -DWITH_GEOTIFF=ON \
  -DGEOTIFF_INCLUDE_DIR=${PREFIX}/include \
  -DGEOTIFF_LIBRARY=${PREFIX}/lib/libgeotiff.dylib \
  -DWITH_GDAL=ON \
  -DGDAL_CONFIG=${PREFIX}/bin/gdal-config \
  -DPROJ4_INCLUDE_DIR=${PREFIX}/include/proj \
  -DPROJ4_LIBRARY=${PREFIX}/lib/proj7 \
  -DWITH_LASZIP=OFF \
  -DWITH_PKGCONFIG=OFF
"

pushd "$liblas_build_dir" > /dev/null

echo
echo "Configuring libLAS..."
$CMAKE -G "Unix Makefiles" $LIBLAS_CONFIGURE_FLAGS "$liblas_source_dir"

echo "Compiling and installing libLAS..."
make &> "${EXTERNAL_DIR}/libLAS_install.log"
if [ $? -ne 0 ]; then
    echo "...libLAS compilation failed. See ${EXTERNAL_DIR}/libLAS_install.log."
    popd > /dev/null
    exit_nice $?
fi

make install &> "${EXTERNAL_DIR}/libLAS_install.log"
if [ $? -ne 0 ]; then
    echo "...libLAS installations failed. See ${EXTERNAL_DIR}/libLAS_install.log."
    popd > /dev/null
    exit_nice $?
fi
echo "...libLAS installed successfully."

popd > /dev/null

export CFLAGS=""
export CXXFLAGS=""
