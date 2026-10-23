# Reference hardware

The first calibration, recordings and benchmark of DartPilot are made with this setup. Benchmark results name the setup they were measured on; other cameras are welcome as [hardware reports](../CONTRIBUTING.md#ways-to-contribute).

The capture settings for this setup are in [ADR 0002](adr/0002-capture-settings.md).

## Board and mounting

| | |
| - | - |
| Board | Target TOR (bristle board with number ring) |
| Surround | Board surround with a camera ring and an LED ring |
| Camera arrangement | 3 cameras in the ring, about 120° apart |
| Viewing angle | Each camera sees the whole board from about 35–45° above the board plane (estimated from images; the extrinsic calibration (#13) gives the exact poses) |
| Lighting | LED ring around the board |

The board is about 650 px wide in each image. That is about **1.9 px/mm across and about 1.1 px/mm along the viewing direction**, where the board appears compressed. A P95 error of 1.5 mm therefore corresponds to roughly 1.5–3 px: tip localisation and calibration have to work at sub-pixel accuracy, and MJPG compression artefacts are a possible limit (see [ADR 0002](adr/0002-capture-settings.md)).

The segment colours repeat every two segments, so they alone leave 10 possible board orientations; the number ring or a user confirmation resolves it (#47).

## Cameras

Three identical generic UVC camera modules.

| Property | Value |
| -------- | ----- |
| Sensor | OmniVision OV9732, 1280×720 native, rolling shutter |
| Lens | 100° field of view (seller's figure, axis not stated) |
| USB ID | `0bda:5844` (Realtek chipset), reported as "Generic USB Camera" |
| Interface | USB 2.0 (480 Mbit/s), UVC 1.00, Linux driver `uvcvideo` |
| Serial number | `200901010001` on every unit, so the serial does not tell the cameras apart |
| Focus | no focus control; set by turning the lens in its thread |
| Gain | no gain control |
| Capture timestamps | driver: monotonic clock, flagged as start of exposure but following the USB delivery (±2 ms); UVC metadata: PTS of the real start of exposure on a 15 MHz camera clock, see [ADR 0005](adr/0005-capture-backend-and-timestamps.md) |

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

### Focus

Set the focus once, at the final camera position, before the intrinsic calibration. Turning the lens changes the focal length and the distortion, so every turn afterwards invalidates the calibration of that camera. The lens is often fixed with a drop of glue at the factory; loosen it carefully. Keep the exposure automatic while focusing (see [Exposure and gain](#exposure-and-gain)); `dartpilot focus` normalises its sharpness measure by brightness, so exposure changes do not mimic a change in focus.

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

## Exposure and gain

Measured 2026-10-23 with the LED ring on, room light as during play, mean brightness of the board area (0–255):

| Exposure | Board brightness | Frame rate |
| -------- | ---------------- | ---------- |
| automatic (`auto_exposure=3`) | 124–135 | 30 fps |
| manual 5–30 ms | 1–12 | 30 fps |
| manual 33 ms | 10–14 | 29 fps |
| manual 100 ms | 36 | 10 fps |
| manual 500 ms | 112 | 2 fps |

Brightness grows linearly with the manual exposure time, and above 33 ms the frame rate drops as expected, so the unit of `exposure_time_absolute` (100 µs) is correct. In automatic mode the camera applies an internal gain of roughly 10× that cannot be set and is not available in manual mode. The standard processing unit does not offer a gain control (bit 9 of `bmControls` 0x157f is not set).

The cameras also have a vendor extension unit (unit 4, GUID `1229a78c-47b4-4094-b0ce-db07386fb938`, two 8-byte controls on selectors 10 and 11), which appears identically in other Realtek-based webcams. It is undocumented and behaves like a command/response mailbox (selector 10 readable, selector 11 not); it was only read, never written.

Automatic exposure is stable for the comparison of frames before and after a throw: between the empty board and the board with three darts, the median absolute difference outside the darts was 1.7/255 in all three cameras. The capture settings follow from this, see [ADR 0002](adr/0002-capture-settings.md).

## Tip visibility

Three darts (treble 20, next to the bull, double 11 next to a wire), automatic exposure, all three cameras:

- The point where each dart enters the board is visible in **all three views**. Since the visible entry point lies on the playing surface, it is the point the geometry projects (z = 0).
- The darts stand out of the board towards the cameras, so their barrels and flights cover large image areas. In one view, the flight of a dart in the near half of the board covered the bull area; a later dart landing there would be hidden in that camera. The three viewing directions provide the redundancy for this, and fusion (#32) has to expect occluded tips.
- The barrels are only a few pixels wide, consistent with the 1–2 px/mm resolution above.

## Open

- Measured field of view and lens distortion, from the intrinsic calibration
- Exact camera positions and viewing angles relative to the board, from the extrinsic calibration (#13)
- Tip visibility in more positions and with darts occluding each other (robustness cases, #29)
