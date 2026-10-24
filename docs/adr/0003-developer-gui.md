# ADR 0003: Developer GUI

- **Status:** accepted
- **Date:** 2026-10-23

## Context

Setting up the cameras already needs a graphical tool: the cameras are told apart only by long `/dev/v4l/by-path` names, the focus is set by turning the lens while watching a sharpness measure, and exposure and white balance have to be fixed by hand ([hardware](../hardware.md)). Later phases need visual diagnostics as well: guided calibration capture, tip candidates with their covariance, reprojection, the throw timeline and replay.

These are developer and tester needs. The user interface for players is a separate product decision ([ADR 0004](0004-user-interface.md)) and talks to the engine only through its API, which does not exist yet. The diagnostics cannot wait for it, and they need direct access to engine internals that the API will never expose.

## Decision

- A developer GUI `dartpilot_setup` under `engine/apps/`, built with **Qt 6**: QML for layout and controls, C++ items for camera images and overlays.
- It links the engine modules directly, without the engine API.
- It starts with camera setup (discovery by USB port, live view, exposure, white balance, focus) and grows with each phase.
- It is a tool for developers and hardware testers, not for players. Nothing in the engine depends on it.

## Alternatives considered

- **Dear ImGui.** Pure C++ and the fastest way to add a new value or overlay, but the result looks like a debug overlay. QML gives a tool that hardware testers from the community can use without explanation.
- **The user GUI (Flutter).** One UI stack fewer, but it would have to wait for the engine API and could only show what the API exposes.
- **OpenCV HighGUI**, as used by the first `dartpilot focus` command. Enough for one image with text, not for several cameras with controls.

## Consequences

- Qt 6 (Core, Gui, Quick, Qml) is a build dependency of this app only. It is built when Qt 6 is found and skipped otherwise, so the engine and its tests build without Qt.
- Camera images are drawn by a C++ item that paints the latest frame and its overlays; QML only arranges the views and controls.
- Code shared with the engine (camera discovery, V4L2 controls, sharpness measure) lives in the engine modules, not in the app.
