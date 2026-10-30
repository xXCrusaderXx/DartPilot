#!/usr/bin/env bash
# Collects the licences of the third-party code linked into the engine into <out dir>/<component>/, the layout the app
# reads for its licence page. Libraries copied next to the engine add theirs in make-appimage.sh.
#
# Usage: collect-licenses.sh <out dir> <OpenCV install prefix> <engine build dir>
set -euo pipefail
out=$1
opencv=$2
build=$3

copy() {
    local component=$1
    shift
    mkdir -p "$out/$component"
    for file in "$@"; do
        if [ ! -f "$file" ]; then
            echo "error: licence file $file is missing" >&2
            exit 1
        fi
        cp "$file" "$out/$component/"
    done
}

if [ -z "$(ls -A "$opencv/share/licenses/opencv4" 2> /dev/null)" ]; then
    echo "error: no licences in $opencv/share/licenses/opencv4 (built by build-opencv.sh?)" >&2
    exit 1
fi
copy OpenCV "$opencv"/share/licenses/opencv4/*
copy IXWebSocket "$build/_deps/ixwebsocket-src/LICENSE.txt"
copy nlohmann-json "$build/_deps/nlohmann_json-src/LICENSE.MIT"
