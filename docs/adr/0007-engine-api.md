# ADR 0007: Engine API

- **Status:** proposed (issue #37)
- **Date:** 2026-10-24

## Context

The player app (ADR 0004) and later integrations need the engine's results while a game is played: where each dart landed, how sure the engine is, when the darts were pulled out, and whether the cameras work. The app runs on the camera computer, on a tablet or in a browser, so the interface has to work over the network. The engine is a C++ program on Linux next to the cameras (ADR 0001); the app is Flutter (Dart).

Two principles from the technical plan shape the interface: results are board points in mm with uncertainty, not only scores, and the engine may abstain instead of guessing.

## Decision

- **Transport: WebSocket**, one connection per client, default port 8484. Text messages are JSON objects; camera previews are binary messages. WebSocket works from Flutter on every target, from a browser without a plug-in, and from Python for tests.
- **The engine does not know games.** It reports darts and takeouts; turns, scores of a game and statistics belong to the client. One engine serves any game and any number of clients.
- **Results as defined elsewhere:** a dart carries its board point in the coordinates and field names of [board-coordinates.md](../board-coordinates.md) and the score of the deterministic scorer (#12), like the result records of [replay-format.md](../replay-format.md). Clients may rescore the board point with their own copy of the scorer; both must agree.
- **Corrections flow back:** a client can correct or reject a dart. The engine stores the correction with the throw in the recorded session, which makes every correction a labelled hard case for the benchmark.
- **Versioning:** the first message names the protocol version `dartpilot/<major>.<minor>`. Minor versions only add messages and fields; clients ignore what they do not know. A major version change breaks compatibility and is a new ADR.
- **Implementation:** the server is part of the engine binary (`dartpilot serve`), with [IXWebSocket](https://github.com/machinezone/IXWebSocket) (BSD-3-Clause) for WebSocket and [nlohmann/json](https://github.com/nlohmann/json) (MIT) for JSON, both fetched with CMake FetchContent and compatible with GPL-3.0-or-later.
- **Simulator:** `dartpilot serve --simulate` produces plausible darts, takeouts and camera states without cameras, and `dartpilot serve --replay <session>` replays a recorded session. Clients are developed and tested against the real protocol before detection exists.

The protocol itself is specified in [engine-api.md](../engine-api.md).

## Alternatives considered

- **gRPC / Protobuf:** strong typing and code generation, but browser clients need a proxy (gRPC-Web), and the tool chain is heavier than the message volume needs (a few messages per throw).
- **REST with polling or Server-Sent Events:** simple, but corrections and previews need a second channel, and polling adds latency to every dart.
- **MQTT:** good for many devices, but needs a broker as a separate service on the user's computer.
- **Game logic in the engine:** fewer messages, but every new game mode would need an engine release, and online multiplayer would have to run through the camera computer.

## Consequences

- The engine gets a network-facing component. It listens on all interfaces only when asked (`--listen 0.0.0.0`); the default is localhost. Authentication is not part of version 1; [SECURITY.md](../../SECURITY.md) already lists the network interface as a topic.
- Two new third-party libraries are added to the build.
- The Flutter app gets an `EngineThrowSource` next to the manual input and keeps manual input for corrections and engine-less play.
- Online multiplayer later sits between apps, not between engine and app: each player's app talks to its own engine.
