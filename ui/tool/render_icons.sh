#!/usr/bin/env bash
# Renders the app icons of every platform from the DartPilot icon (needs rsvg-convert and ImageMagick).
# Run from ui/ after changing engine/apps/dartpilot_setup/icons/dartpilot.svg or assets/icon/dartpilot-foreground.svg.
set -euo pipefail
full=../engine/apps/dartpilot_setup/icons/dartpilot.svg
foreground=assets/icon/dartpilot-foreground.svg
background='#161c26'
res=android/app/src/main/res

# Android: the full icon (48 dp) for launchers without adaptive icons, and the adaptive foreground layer (108 dp)
for entry in mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432; do
    IFS=: read -r density icon layer <<< "$entry"
    rsvg-convert -w "$icon" "$full" -o "$res/mipmap-$density/ic_launcher.png"
    mkdir -p "$res/drawable-$density"
    rsvg-convert -w "$layer" "$foreground" -o "$res/drawable-$density/ic_launcher_foreground.png"
done

# Web: favicon and app icons; the maskable ones fill the whole square
rsvg-convert -w 32 "$full" -o web/favicon.png
rsvg-convert -w 192 "$full" -o web/icons/Icon-192.png
rsvg-convert -w 512 "$full" -o web/icons/Icon-512.png
for size in 192 512; do
    rsvg-convert -w "$size" -b "$background" "$foreground" -o "web/icons/Icon-maskable-$size.png"
done

# Windows: one .ico with the usual sizes
tmp=$(mktemp -d)
for size in 16 24 32 48 64 128 256; do
    rsvg-convert -w "$size" "$full" -o "$tmp/$size.png"
done
magick "$tmp"/{16,24,32,48,64,128,256}.png windows/runner/resources/app_icon.ico
rm -r "$tmp"

# Linux: the window icon and the icon of the desktop entry
rsvg-convert -w 256 "$full" -o linux/packaging/io.github.xxcrusaderxx.dartpilot.png
