# DartPilot player app

Flutter app for playing with DartPilot ([ADR 0004](../docs/adr/0004-user-interface.md)). Targets: Linux, Windows, web and Android.

Games: X01, Cricket, Around the Clock and free throwing. Until the engine API (#37) exists, darts are entered by tapping the board or with the keypad. Every dart becomes a board point in millimetres and is scored by a port of the engine's scorer (`lib/src/board/scoring.dart`), so manual input and engine results take the same path.

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
| `lib/src/games/` | Game rules as plain Dart, without widgets |
| `lib/src/screens/` | Screens: setups and one game screen per mode |
| `lib/src/widgets/` | Shared widgets: player list, winner dialog |
| `lib/l10n/` | English and German texts (`*.arb`); `flutter gen-l10n` regenerates the Dart files |
