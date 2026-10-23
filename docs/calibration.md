# Calibration

DartPilot calibrates each camera in two steps, both in the developer GUI `dartpilot_setup` ([ADR 0003](adr/0003-developer-gui.md)):

1. **Intrinsic calibration** (#44, #45): focal length, principal point and lens distortion of one camera, from views of a ChArUco pattern.
2. **Extrinsic calibration** (#13): each camera's pose relative to the board, from the dartboard itself. Not available yet.

## Calibration pattern

![ChArUco pattern](calibration/charuco-10x7-DICT_4X4_50-marker-0.70.png)

[charuco-10x7-DICT_4X4_50-marker-0.70.png](calibration/charuco-10x7-DICT_4X4_50-marker-0.70.png): ChArUco, 10 × 7 squares, dictionary `DICT_4X4_50`, markers 70 % of the square size. The detector expects exactly this pattern; patterns from other generators may differ in layout or marker IDs.

- **Phone or tablet:** open the file (the setup GUI shows a QR code for it), full screen, landscape, medium brightness (about 50 %), auto-rotation, auto-brightness, dark mode and night light off. A tablet is easier: a phone shows the markers so small that it has to come close to the camera, where the image gets soft. Hold a phone about 20 to 30 cm away.
- **Second display:** "Show full screen" on the intrinsic calibration page.
- **Print:** lay the print flat on glass or a table top. Its size does not matter for the intrinsics.

The file is generated with `dartpilot pattern docs/calibration/charuco-10x7-DICT_4X4_50-marker-0.70.png`; a test checks that it matches the pattern the detector expects.

## Capturing views

Set the focus first ([hardware](hardware.md)); it must not change afterwards. Keep the exposure automatic: the reference cameras amplify only in automatic mode, and the intrinsics do not depend on the exposure.

- Hold the pattern about 20 to 40 cm in front of the camera, so that it fills a third to two thirds of the image width. Closer than about 20 cm the image gets soft and fewer markers are recognised.
- Cover the whole image: centre, corners and edges. The lens distorts most at the edges.
- Tilt the pattern by 30 to 45 degrees in all directions and vary the distance; tilted views separate the focal length from the distance.
- Hold still for a moment at each pose; the view is captured automatically.
- 15 to 25 views are enough. After calibrating, remove views marked red and calibrate again.

The calibration is stored per USB port in `~/.local/share/dartpilot/calibration/intrinsics-usb-<port>.yml`, together with the views it was computed from.
