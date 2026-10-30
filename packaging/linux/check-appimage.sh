#!/usr/bin/env bash
# Checks that every program and library in an AppImage finds the libraries it links, on the system this runs on.
# Run on a clean system with only a desktop's base (GTK 3) installed, not on the one that built it.
#
# Usage: check-appimage.sh <.AppImage>
set -euo pipefail
image="$(readlink -f "$1")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"
"$image" --appimage-extract > /dev/null
root="$work/squashfs-root/usr/lib/dartpilot"
test -x "$root/engine/dartpilot"

failed=0
while IFS= read -r -d '' file; do
    # libdartjni is loaded only where a Java VM exists (Android); Linux never opens it.
    [ "$(basename "$file")" = libdartjni.so ] && continue
    file -b "$file" | grep -q '^ELF' || continue
    if missing="$(ldd "$file" 2>&1 | grep 'not found')"; then
        echo "::error::${file#"$root"/}: $missing"
        failed=1
    fi
done < <(find "$root" -type f \( -perm -u+x -o -name '*.so*' \) -print0)
exit $failed
