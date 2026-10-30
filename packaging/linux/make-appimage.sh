#!/usr/bin/env bash
# Packs the Linux app bundle (flutter build linux, with the engine in engine/) into an AppImage.
#
# The bundle keeps its layout under usr/lib/dartpilot, because the app finds its data, its libraries and the engine
# next to its own program. Libraries the engine needs beyond a desktop's base system (glibc, libstdc++, GTK 3 and
# what GTK itself needs) are copied to engine/lib; OpenCV is linked statically (build-opencv.sh). The app needs only
# GTK 3 and Flutter's own libraries, which the bundle already carries.
#
# Usage: make-appimage.sh <bundle dir> <output .AppImage> <appimagetool> <runtime file>
set -euo pipefail
bundle=$1
output=$2
appimagetool=$3
runtime=$4
here="$(cd "$(dirname "$0")" && pwd)"
app_id=io.github.xxcrusaderxx.dartpilot
packaging="$here/../../ui/linux/packaging"

if [ ! -x "$bundle/dartpilot-app" ] || [ ! -x "$bundle/engine/dartpilot" ]; then
    echo "error: $bundle lacks dartpilot-app or engine/dartpilot" >&2
    exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
appdir="$work/DartPilot.AppDir"
prefix="$appdir/usr/lib/dartpilot"
mkdir -p "$prefix" "$appdir/usr/share/applications" "$appdir/usr/share/icons/hicolor/256x256/apps"
cp -a "$bundle/." "$prefix/"

# Provided by every desktop that can show the app: glibc, the C++ runtime, and the GTK 3 stack with X11/Wayland,
# graphics, fonts, D-Bus and systemd. Bundling these breaks more systems than it helps (see the AppImage excludelist).
host='^(ld-linux.*|libc|libm|libmvec|libdl|libpthread|librt|libresolv|libutil|libanl|libnss_.*|libstdc\+\+|libgcc_s'
host+='|libGL.*|libEGL|libOpenGL|libdrm|libgbm|libvulkan|libX.*|libxcb.*|libxkbcommon.*|libwayland-.*'
host+='|libgtk-3|libgdk-3|libgdk_pixbuf-2\.0|libglib-2\.0|libgobject-2\.0|libgio-2\.0|libgmodule-2\.0|libgthread-2\.0'
host+='|libpango.*|libcairo.*|libharfbuzz|libfontconfig|libfreetype|libfribidi|libpixman-1|libatk.*|libatspi|libepoxy'
host+='|libthai|libdatrie|libgraphite2|libpng16|libjpeg|libexpat|libffi|libpcre.*|libz|libbz2|liblzma|libzstd'
host+='|libbrotli.*|libmount|libblkid|libselinux|libuuid|libdbus-1|libsystemd|libudev|libcap|libgcrypt|libgpg-error'
host+='|liblz4|libasound)$'

# Copies what the engine links beyond the host's libraries, and what those link in turn.
mkdir -p "$prefix/engine/lib"
queue=("$prefix/engine/dartpilot")
while [ ${#queue[@]} -gt 0 ]; do
    file=${queue[0]}
    queue=("${queue[@]:1}")
    while read -r name path; do
        name=${name##*/}
        if [[ "${name%%.so*}" =~ $host ]] || [ -e "$prefix/engine/lib/$name" ]; then
            continue
        fi
        if [ "$path" = "not" ]; then
            echo "error: $file needs $name, which is not installed" >&2
            exit 1
        fi
        cp -L "$path" "$prefix/engine/lib/$name"
        patchelf --set-rpath '$ORIGIN' "$prefix/engine/lib/$name"
        queue+=("$prefix/engine/lib/$name")
    done < <(ldd "$file" | awk '/=>/ { print $1, $3 }')
done
patchelf --set-rpath '$ORIGIN/lib' "$prefix/engine/dartpilot"
echo "Bundled with the engine: $(ls "$prefix/engine/lib" | tr '\n' ' ')"

cp "$packaging/$app_id.desktop" "$appdir/$app_id.desktop"
cp "$packaging/$app_id.desktop" "$appdir/usr/share/applications/"
cp "$packaging/$app_id.png" "$appdir/$app_id.png"
cp "$packaging/$app_id.png" "$appdir/usr/share/icons/hicolor/256x256/apps/"
ln -s "$app_id.png" "$appdir/.DirIcon"
cat > "$appdir/AppRun" << 'APPRUN'
#!/bin/sh
here="$(dirname "$(readlink -f "$0")")"
exec "$here/usr/lib/dartpilot/dartpilot-app" "$@"
APPRUN
chmod +x "$appdir/AppRun"

ARCH=x86_64 "$appimagetool" --no-appstream --runtime-file "$runtime" "$appdir" "$output"
