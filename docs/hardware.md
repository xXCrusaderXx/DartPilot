# Reference hardware

This is the setup DartPilot is developed and benchmarked on. Other setups will work as long as they meet the requirements below; reports of other cameras are welcome (see [CONTRIBUTING.md](../CONTRIBUTING.md#ways-to-contribute)).

The capture settings derived from it are in [ADR 0002](adr/0002-capture-settings.md).

## Board and mounting

| | |
| - | - |
| Board | Target TOR (bristle board with number ring) |
| Surround | Board surround with a camera ring and an LED ring |
| Camera arrangement | 3 cameras in the ring, about 120° apart |
| Viewing angle | Each camera sees the whole board from about 35–45° above the board plane (estimated from images; the extrinsic calibration (#13) will give exact poses) |
| Lighting | LED ring around the board |

Open: distance of the cameras to the board centre and exact elevation angles (follow from the extrinsic calibration), name of the camera ring product.

## Cameras

All three cameras are identical.

| Property | Value |
| -------- | ----- |
| USB ID | `0bda:5844` (Realtek), product string "USB Camera" |
| Driver | `uvcvideo` (UVC), one video node and one UVC metadata node per camera |
| USB | 2.0 High Speed (480 Mbit/s), 500 mA |
| Serial number | `200901010001` on **all three** cameras – not usable to tell them apart |
| Lens | Fixed focus, no zoom (no focus or zoom controls) |

### Formats

| Format | Resolutions | Frame rate |
| ------ | ----------- | ---------- |
| MJPG | 1280×720, 960×540, 848×480, 800×600, 640×480, 352×288, 320×240, 176×144, 160×120 | 30 fps for all |
| YUYV | 1280×720 | 10 fps |
| YUYV | 960×540, 848×480, 800×600 | 15 fps |
| YUYV | 640×480 and smaller | 30 fps |

Uncompressed 1280×720 at 30 fps would need about 440 Mbit/s per camera, more than USB 2.0 offers for three cameras, so full resolution at 30 fps is only available as MJPG.

### Controls

| Control | Range | Default | Notes |
| ------- | ----- | ------- | ----- |
| `auto_exposure` | 1 = manual, 3 = aperture priority | 3 | Manual mode works |
| `exposure_time_absolute` | 0–10000 (100 µs units) | 166 | Only active in manual mode |
| `exposure_dynamic_framerate` | bool | 0 | Must stay off, otherwise the frame rate drops in low light |
| `white_balance_automatic` | bool | 1 | |
| `white_balance_temperature` | 2800–6500 K | 4600 | Only active with automatic white balance off |
| `brightness`, `contrast`, `saturation`, `hue`, `gamma`, `sharpness` | various | | Image processing in the camera; `sharpness` may affect sub-pixel accuracy |
| `power_line_frequency` | disabled / 50 Hz / 60 Hz | 50 Hz | |
| `backlight_compensation` | 0–1 | 0 | |

There is **no gain control**. Brightness has to come from exposure time and lighting.

### Timestamps

`uvcvideo` delivers buffers with `V4L2_BUF_FLAG_TIMESTAMP_MONOTONIC` and `V4L2_BUF_FLAG_TSTAMP_SRC_SOE`: the timestamp is the **start of exposure** on the host's monotonic clock, derived by the driver from the camera's UVC clock (SCR/PTS). Frame intervals in a first test alternated between about 32 and 36 ms at 30 fps, so the timestamps are quantised or jittery by about 4 ms. How well they match the real exposure time across cameras is the subject of #3 and #20.

## USB topology

All three cameras are connected through a chain of three USB 2.0 hubs to one host port and share its 480 Mbit/s:

```text
host port (usb-0000:0e:00.4-2)
└─ hub 4-port ─ hub 2-port ─ hub 4-port ─┬─ port 2: camera (…-2.4.3.1.2)
                                         ├─ port 3: camera (…-2.4.3.1.3)
                                         └─ port 4: camera (…-2.4.3.1.4)
```

Because the serial numbers are identical, a camera can only be identified by its **USB port path**. Re-plugging cables swaps cameras. Calibrations are therefore stored per port path and checked against the image content: each camera sees the board from a different side, which the wire detection (#47) recognises.

## First measurements

| Test | Result |
| ---- | ------ |
| All three cameras at 1280×720 MJPG, 30 fps, at the same time, 10 s | 300 of 300 frames per camera, 30.0 fps, no drops |
| MJPG frame size at 1280×720 | about 25–55 KB |
| Board size in the image | about 650 px wide, i.e. about 1.9 px/mm across and about 1.1 px/mm along the viewing direction |

The last line matters for the targets: a P95 error of 1.5 mm corresponds to roughly 1.5–3 px, so tip localisation and calibration have to work at sub-pixel accuracy. MJPG compression artefacts may limit this; #3 compares MJPG against YUYV at 10 fps.

## Still to check

- Whether the tip is visible in all three views with darts in the board (sample frames without people).
- Stability over long sessions and under system load (#7).
- Whether the hub chain causes drops when the host is busy; a direct connection or separate host controllers may be needed.
