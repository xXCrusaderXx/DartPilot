# DartPilot player app

Flutter app for playing with DartPilot ([ADR 0004](../docs/adr/0004-user-interface.md)). Targets: Linux, Windows, web and Android.

Games: X01, Cricket (also cut-throat), Around the Clock, Shanghai, Bob's 27, Halve-It and Killer, against other players or bots. Training: free throwing, grouping, doubles practice and a checkout trainer, each dart measured in millimetres against its target. Statistics over games with CSV and JSON export, and a score caller.

Darts come from the engine over the engine API ([docs/engine-api.md](../docs/engine-api.md)) when the app is connected, and can always be entered by tapping the board or with the keypad. Every dart becomes a board point in millimetres and is scored by a port of the engine's scorer (`lib/src/board/scoring.dart`), so manual input and engine results take the same path.

On Linux the app can start the engine itself, or connect to one in the home network (pairing with a PIN). To play against the simulated engine, start it and press **Connect** on the home screen:

```sh
../build/engine/apps/dartpilot_cli/dartpilot serve --simulate             # drawn camera images
../build/engine/apps/dartpilot_cli/dartpilot serve --simulate --cameras   # live images of the real cameras
```

**Cameras** on the home screen shows the camera images once connected.

```sh
flutter run -d linux     # run on the desktop
flutter test             # unit and widget tests
flutter analyze
dart format lib/main.dart lib/src test   # 120 columns, see analysis_options.yaml
```

Layout:

| Path | Content |
| ---- | ------- |
| `lib/src/board/` | Board geometry, scorer, throws, the interactive dartboard |
| `lib/src/input/` | Keypad and the switchable input panel |
| `lib/src/engine/` | Engine connection (WebSocket) and its messages, discovery in the network, pairing, starting a local engine |
| `lib/src/games/` | Game rules as plain Dart, without widgets |
| `lib/src/bots/` | Bots to play against, as plain Dart |
| `lib/src/stats/` | Game records, player and precision statistics, export |
| `lib/src/sound/` | Score caller |
| `lib/src/screens/` | Screens: setups and one game screen per mode |
| `lib/src/widgets/` | Shared widgets |
| `lib/src/display.dart`, `lib/src/theme.dart` | Window size classes and the app's colours |
| `lib/l10n/` | English and German texts (`*.arb`); `flutter gen-l10n` regenerates the Dart files |
