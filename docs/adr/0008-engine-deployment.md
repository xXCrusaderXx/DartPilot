# ADR 0008: Engine deployment – in the app and remote

- **Status:** accepted; the Android part was confirmed by the feasibility spike (#104, [android.md](../android.md)): three cameras at 30 fps through libuvc on a phone
- **Date:** 2026-10-25

## Context

DartPilot should work with whatever the player has:

- **Only a phone or tablet:** the cameras plug into the phone (USB hub), and the phone runs the engine and the game.
- **One computer:** Linux, Windows or a Raspberry Pi runs the engine and shows the app.
- **A host and a display:** a computer or a Pi next to the board runs the engine with the cameras; a tablet, phone or another computer shows the game.

The engine is a C++ program (ADR 0001) that clients reach through the engine API over WebSocket (ADR 0007). The player app is Flutter (ADR 0004). Capture uses V4L2 with UVC metadata (ADR 0005), which exists only on Linux.

## Decision

### One engine, one protocol, two ways to reach it

The app always talks to an engine through the engine API. An engine runs either

- **in the app**: started and stopped by the app on the same device; the app connects to `ws://127.0.0.1:<port>`, or
- **remote**: on another device in the network; the app connects to its address.

Games, corrections and previews work the same in both cases, because they only see the protocol. The app offers both on its start page: *Engine on this device* (where the platform supports it) and *Engine in the network*.

### How the app runs its own engine

| Platform | Engine in the app | Capture backend |
| -------- | ----------------- | --------------- |
| Linux (desktop, Raspberry Pi) | The app starts the `dartpilot` binary that ships with it as a child process (`dartpilot serve`) and stops it on exit. | V4L2 + UVC metadata (ADR 0005) |
| Windows | The same, with `dartpilot.exe`. | Media Foundation (new backend; timestamps to be measured like ADR 0005) |
| Android | The engine is built with the NDK as a shared library inside the app and runs `serve` on a background thread; the app connects over localhost. A process would not get USB permissions on Android. | libuvc on the file descriptor that the Android USB Host API hands out after the user grants permission per camera; libuvc delivers the UVC payload headers, so PTS/SCR timestamps stay available. Camera2 "external camera" is a fallback where libuvc fails. |
| iOS, web | No engine in the app; remote only. | – |

The capture backends implement the existing `capture::FrameSource` interface, so everything above capture stays the same. OpenCV is available for Android and Windows.

### Portability of the engine

- The pipeline modules (geometry, tip candidates, replay, scoring, session) are portable C++20 with OpenCV and `std::filesystem`; only a few POSIX calls (`gmtime_r`, `clock_gettime`, signal handling) need wrappers for Windows.
- **Data directory:** calibrations (`intrinsics-usb-<port>.yml`, `board-usb-<port>.yml`, `extrinsics.yml`, check and validation logs) and sessions live in one platform-aware directory provided by the engine, not by Qt or the CLI: the XDG data directory on Linux, `%LOCALAPPDATA%` on Windows, and on Android the app's files directory handed in by the app (#112).
- **Camera identity:** calibrations and sessions are keyed by the camera's USB port path, because the reference cameras share one serial number (ADR 0005, hardware.md). Every capture backend provides an equally stable port path: the USB bus and port chain of the `UsbDevice` on Android, the location path of the device instance on Windows (#112).
- The developer GUI (`dartpilot_setup`, Qt) stays a Linux tool for now; calibration on other platforms goes through the player app or a Linux machine.

### Remote engines

- **Engine host:** any of the platforms above, including a headless Raspberry Pi, runs `dartpilot serve --listen 0.0.0.0`.
- **Finding engines:** engines announce themselves with mDNS/DNS-SD as `_dartpilot._tcp`; the app lists engines in the network and still accepts a typed address.
- **Pairing:** an engine that listens on the network requires a pairing: it shows a short PIN (in its log or GUI), the app sends it once and gets a token for later connections. This closes the "no authentication" gap of protocol version 1 for network use; localhost stays without pairing. It is a protocol minor addition and goes into `docs/engine-api.md` when implemented.

## Feasibility to confirm first (Android)

Before Android is built, a spike measures on a real phone (#104):

1. One, then three UVC cameras through a powered USB hub with libuvc: frame rate, lost frames, MJPG at 1280×720.
2. PTS and SCR in the payload headers, and how they map to the phone's monotonic clock.
3. CPU load and battery drain while streaming three cameras, and with JPEG decoding at the detection rate.
4. USB permission flow per camera and behaviour on unplugging.

If libuvc does not reach three cameras at 30 fps, the alternatives are fewer cameras, a lower resolution, or Android as a display only.

**Result (2026-10-25, Pixel 10a, Android 17, [android.md](../android.md)):**
- libuvc reached three cameras at 30.00 fps each behind one hub, with no lost or broken frame.
- CPU load for the transport was 21.6 %, and the battery drained about 750 mA.
- The Android engine (#106) is built as decided above.
- Still to measure: JPEG decoding at the detection rate, re-plugging a camera, and the PTS/SCR timestamps through libuvc (a spike bug hid them in the first runs).

## Alternatives considered

- **A separate engine app on Android with the player app as a client:** two installs and an inter-app connection for no gain; the localhost connection inside one app already separates them.
- **Engine logic in Dart:** would duplicate the C++ pipeline and its benchmarks.
- **Flutter FFI calls instead of localhost WebSocket inside the app:** fewer moving parts per call, but a second interface to maintain next to the protocol. Localhost keeps one interface and makes "in the app" and "remote" behave identically.

## Consequences

- The work is planned in the roadmap's platform track: *Platform: remote play and engine choice* first, because it needs no new capture backend, then *Platform: engine on Android and Windows*.

- The engine build gains Android (NDK) and Windows targets; CI builds them once they exist.
- New capture backends: libuvc (Android), Media Foundation (Windows). Their timestamp quality is measured and documented like ADR 0005.
- The app gains an engine manager per platform (start, stop, port, logs) and an engine list from mDNS.
- Pairing and discovery extend the engine API.
- Recorded sessions and calibrations live on the device that runs the engine.
