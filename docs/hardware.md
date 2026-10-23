# Reference hardware

The first calibration, recordings and benchmark of DartPilot are made with this setup. Benchmark results name the setup they were measured on; other cameras are welcome as [hardware reports](../CONTRIBUTING.md#ways-to-contribute).

## Cameras

Three identical generic UVC camera modules.

| Property | Value |
| -------- | ----- |
| Sensor | OmniVision OV9732, 1280×720 native, rolling shutter |
| Lens | 100° field of view (seller's figure, axis not stated) |
| USB ID | `0bda:5844` (Realtek chipset), reported as "Generic USB Camera" |
| Interface | USB 2.0 (480 Mbit/s), UVC 1.00, Linux driver `uvcvideo` |
| Serial number | `200901010001` on every unit, so the serial does not tell the cameras apart |
| Focus | fixed, no focus control |
| Gain | no gain control |
| Capture timestamps | monotonic clock, taken at start of exposure (`V4L2_BUF_FLAG_TSTAMP_SRC_SOE`) |

### Modes

| Format | Resolution | FPS |
| ------ | ---------- | --- |
| MJPG | 1280×720 and every smaller mode down to 160×120 | 30 |
| YUYV | 1280×720 | 10 |
| YUYV | 960×540, 848×480, 800×600 | 15 |
| YUYV | 640×480 and smaller | 30 |

The reference mode is **MJPG 1280×720 at 30 fps**, the sensor's native resolution. Uncompressed 720p only reaches 10 fps.

The rolling shutter exposes the rows one after another, so a dart in flight appears skewed. Frames of the resting dart after the throw are not affected.

### Controls

| Control | Range | Default |
| ------- | ----- | ------- |
| `auto_exposure` | 1 = manual, 3 = aperture priority | 3 |
| `exposure_time_absolute` | 0–10000 (units of 100 µs) | 166 |
| `exposure_dynamic_framerate` | on/off | on when connected |
| `white_balance_automatic` | on/off | on |
| `white_balance_temperature` | 2800–6500 K | 4600 |
| `brightness`, `contrast`, `saturation`, `hue`, `gamma`, `sharpness` | image processing in the camera | |
| `power_line_frequency` | disabled, 50 Hz, 60 Hz | 50 Hz |

`exposure_dynamic_framerate` is on after every connect. In room light it lowers the frame rate to about 16.7 fps with intervals of up to 64 ms. Capture must switch it off, and should fix exposure and white balance, so that the frame rate and the image stay constant over a recording.

## Connection

The three cameras share one USB 2.0 hub. Cameras are identified by their USB port, through `/dev/v4l/by-path/`, never by `/dev/videoN`, which can change between boots. A camera keeps its port for as long as its calibration is used.

Each camera exposes two device nodes: the first (`video-index0`) delivers images, the second (`video-index1`) only UVC metadata.

## Measured

2026-10-23, Arch Linux, kernel 7.2.9, all three cameras streaming MJPG 1280×720 at once with `v4l2-ctl`, 300 frames each, `exposure_dynamic_framerate` off:

| Camera | Effective FPS | Longest frame interval | Lost frames |
| ------ | ------------- | ---------------------- | ----------- |
| 1 | 30.01 | 36 ms | 0 |
| 2 | 30.01 | 36 ms | 0 |
| 3 | 30.01 | 36 ms | 0 |

The time offset between the cameras has not been measured yet (see [technical plan, section 5.1](technical_plan.md#51-capture-and-timing)).

## Open

- Measured field of view and lens distortion, from the intrinsic calibration
- Camera positions and viewing angles relative to the board
