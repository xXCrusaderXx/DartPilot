# The app on Android

This page records how the player app runs on a phone with the engine on another computer (#114, [ADR 0008](adr/0008-engine-deployment.md)): how to set it up, and what the phone has to do for the camera previews. The measurements tell whether a phone could decode three camera streams itself, which the Android engine (#104, #106) needs.

## Setup with a USB cable

No USB adapter is needed: the phone connects to the computer by USB for debugging, and adb forwards the engine port.

1. On the phone, enable the developer options (tap *Build number* seven times) and *USB debugging*; allow the computer when asked.
2. On the computer, accept the Android SDK licences once: `flutter doctor --android-licenses`.
3. Start the engine: `dartpilot serve --simulate --cameras`.
4. Forward the port and install the app:

   ```sh
   adb reverse tcp:8484 tcp:8484
   (cd ui && flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk)
   ```

5. In the app, connect to `ws://localhost:8484/`.

`adb reverse` is lost whenever the phone drops the USB connection (cable, USB mode change); run it again and reconnect. Over Wi-Fi, the engine listens with `--listen 0.0.0.0` and the app finds it with the network search (#109).

## Measurements

Pixel 10a, Android 17, 8 cores, 1080 × 2424 px at about 2.6 device pixels per logical pixel; debug build; engine with three cameras (MJPG 1280 × 720, 30 fps) on the computer, over `adb reverse`. CPU is the app process's user and system time over 20 s, as a share of one core.

| View | Previews | Before | After |
| ---- | -------- | ------ | ----- |
| Cameras page, three panels | 3 × 640 px at 10 fps | 100 % | 87 % |
| One camera full screen | 1 × 1280 × 720 at 15 fps (before: plus 2 × 640 px at 10 fps underneath) | 94 % | 62 % |

Memory (resident) stayed between 580 and 700 MB.

Where the time goes (three panels, before): the Dart UI thread 36 % (receiving and splitting the binary messages, rebuilding), a Dart worker 16 %, two image-decoding threads 13 % each, the raster thread 12 %. The work is already spread over several threads; none is near a full core, so moving work to more threads would not lower the load.

What changed between *before* and *after*:

- Panels decode their preview at the size they are shown and ask the engine for no more pixels than they need (in steps of 160 px up to 640 px). On this phone a full-width panel is about 1000 device pixels, more than the 640 px preview, so this only helps on smaller or less dense screens.
- Panels pause while a camera is shown full screen. This is most of the gain for the full-screen view.

Further savings, if needed: a lower preview rate for the overview (5 instead of 10 fps halves the decoding), or hardware decoding.

## What this means for an engine on the phone

Decoding one 1280 × 720 stream at 15 fps costs the app about half a core (full screen, after). Three streams at 30 fps, as the engine needs them, would be roughly 6 × that: about three cores of eight for JPEG decoding alone, before detection. That is possible on this phone but leaves little room; the Android spike (#104) should measure the decoding inside the engine (libjpeg-turbo, or the cameras' hardware path) rather than estimate it from the app.
