# ADR 0004: User interface

- **Status:** accepted
- **Date:** 2026-10-23

## Context

[ADR 0001](0001-language-stack.md) left the user interface open and required that it talk to the engine through an API, so that the toolkit does not affect the engine. Players will use DartPilot on different devices: the computer the cameras are connected to, a touch screen or a tablet next to the board, a browser, and later online multiplayer.

The developer and setup tool is a separate decision ([ADR 0003](0003-developer-gui.md)).

## Decision

- The user interface is built with **Flutter** (Dart).
- Targets: Linux, Windows, web and Android.
- It talks to the engine only through the engine API (#37), for example JSON over WebSocket. Camera previews come through the same API as compressed frames.
- The engine stays a Linux program next to the cameras. A UI on another device connects to it over the network.

## Alternatives considered

- **Qt 6 / QML.** Already used for the developer GUI, and strong on desktop and embedded touch screens. Web and Android deployment is possible but much more effort than with Flutter.
- **A plain web UI** (TypeScript). Runs everywhere through a browser, but a native app on a tablet or desktop needs a second wrapper, and the project would add a JavaScript tool chain.

## Consequences

- The engine API (#37) is a prerequisite for the user interface and is designed to be toolkit-neutral.
- The Flutter app lives in its own directory (`ui/`), with its own build, lint and test steps in CI once it exists.
- Code style and contribution rules for Dart are added when the first Flutter code is merged.
