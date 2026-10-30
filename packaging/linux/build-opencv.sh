#!/usr/bin/env bash
# Builds the OpenCV modules the engine needs as static libraries, so the packaged engine needs no OpenCV on the
# player's system. Video comes from the engine's own V4L2 capture and images from OpenCV's bundled codecs, so FFmpeg,
# GStreamer, TBB, IPP (a binary download) and OpenCL are left out. highgui uses the GTK 3 the app needs anyway.
#
# Usage: build-opencv.sh <opencv source dir> <install prefix>
set -euo pipefail
src=$1
prefix=$2
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT

cmake -S "$src" -B "$build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_LIST=core,imgproc,imgcodecs,videoio,highgui,calib3d,objdetect \
    -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOCS=OFF \
    -DBUILD_opencv_apps=OFF -DBUILD_JAVA=OFF -DBUILD_opencv_python3=OFF -DBUILD_opencv_python2=OFF \
    -DBUILD_ZLIB=ON -DBUILD_PNG=ON -DBUILD_JPEG=ON \
    -DWITH_V4L=ON -DWITH_GTK=ON -DWITH_GTK_2_X=OFF -DWITH_QT=OFF -DWITH_OPENGL=OFF \
    -DWITH_FFMPEG=OFF -DWITH_GSTREAMER=OFF -DWITH_1394=OFF -DWITH_GPHOTO2=OFF -DWITH_VA=OFF -DWITH_VA_INTEL=OFF \
    -DWITH_IPP=OFF -DWITH_ITT=OFF -DWITH_TBB=OFF -DWITH_OPENMP=OFF -DWITH_OPENCL=OFF -DWITH_LAPACK=OFF \
    -DWITH_EIGEN=OFF -DWITH_PROTOBUF=OFF -DWITH_ADE=OFF -DWITH_VTK=OFF \
    -DWITH_TIFF=OFF -DWITH_WEBP=OFF -DWITH_OPENJPEG=OFF -DWITH_JASPER=OFF -DWITH_OPENEXR=OFF -DWITH_AVIF=OFF \
    -DWITH_JPEGXL=OFF -DWITH_IMGCODEC_HDR=OFF -DWITH_IMGCODEC_SUNRASTER=OFF -DWITH_IMGCODEC_PXM=OFF \
    -DWITH_IMGCODEC_PFM=OFF -DOPENCV_GENERATE_PKGCONFIG=OFF
cmake --build "$build"
cmake --install "$build"
