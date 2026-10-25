# Android

Whether a phone can run the cameras for DartPilot, measured before the Android engine is built (#104, ADR 0008).

## The spike

`engine/android/spike/` holds a native library (`libdartpilot_spike.so`). It builds libusb 1.0.27 and libuvc with the NDK and opens each camera through `uvc_wrap()` on the file descriptor that the Android USB Host API grants after the user's permission. The cameras stream MJPG 1280×720 at 30 fps, and the library measures them. A small Java app around it (`engine/android/spike/app/`) asks for the permissions, runs the measurement off the UI thread, reads the battery before and after, and logs the result as JSON (logcat tag `DartPilotSpike`).

Measured per camera: frames, frame rate, frame intervals (p50, p95, max), gaps in the frame sequence, incomplete JPEGs (missing SOI/EOI), bytes per frame, and how many frames carried a PTS and an SCR in their UVC payload headers. For the process: CPU time over wall time, summed over all cores.

## Results

Pixel 10a, Android 17. The three reference cameras sit behind the maintainer's USB hub on a USB-C to USB-A adapter; the phone was not charging. Measured 2026-10-25.

| Run | Camera | Frames | fps | Interval p50 / p95 / max | Gaps | Broken JPEG | Frame size |
| - | - | - | - | - | - | - | - |
| 1 camera, 30 s | 0 | 894 | 30.01 | 32.0 / 36.1 / 37.0 ms | 0 | 0 | 31.2 KB |
| 3 cameras, 60 s | 0 | 1796 | 30.00 | 32.1 / 36.2 / 40.2 ms | 0 | 0 | 31.8 KB |
| | 1 | 1797 | 30.00 | 32.1 / 36.1 / 70.1 ms | 0 | 0 | 31.3 KB |
| | 2 | 1798 | 30.00 | 32.1 / 36.1 / 75.0 ms | 0 | 0 | 30.7 KB |

| Run | CPU (process, all cores) | Battery drain | Battery temperature |
| - | - | - | - |
| 1 camera | 7.1 % | about 300 mA | – |
| 3 cameras | 21.6 % | about 745 mA (charge counter 2 035 000 → 2 022 500 µAh in 60.3 s) | 28.3 °C, unchanged |

- **Three cameras at 30 fps work.** The isochronous bandwidth was enough for 3 × MJPG 720p30 behind one hub on one bus, without a lost or broken frame.
- **Timing:** an occasional single frame arrives one frame period late (70–75 ms), but none is lost.
- **Power:** about 750 mA for three cameras, i.e. a 5000 mAh battery lasts roughly 6 hours on transport alone. Playing longer needs a hub with its own supply that also charges the phone.
- **Not measured yet:** decoding the JPEGs at the detection rate. The 21.6 % CPU are transport only. Also not yet tried: unplugging and re-plugging a camera.
- **Timestamps:** the first runs reported no PTS/SCR. The cause was in the spike, not in the cameras: libuvc never sets `frame->source`. A re-run with the fix is pending; on the PC the same cameras deliver PTS and SCR (ADR 0005).

## Building

```sh
cmake -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release engine/android/spike
cmake --build build
```

The spike app builds it through Gradle (`externalNativeBuild`). libusb and libuvc are fetched at configure time.
