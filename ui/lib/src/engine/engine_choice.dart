// How the darts are counted and which engine the app uses (#105): by hand, its own engine on this device, or one in
// the network; remembered between starts.
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'engine_connection.dart';
import 'engine_manager.dart';

enum EngineMode { thisDevice, network }

/// The player's last choice, stored on the device
class EngineSettings extends ChangeNotifier {
  EngineSettings({
    this.mode = EngineMode.network,
    this.url = EngineConnection.defaultUrl,
    this.simulate = false,
    this.cameras = true,
    this.chosen = false,
    this.byHand = false,
    this.store = true,
  });

  EngineMode mode;
  String url;

  /// The player chose how the darts are counted; until then the app opens on that choice
  bool chosen;

  /// Darts are entered by hand: the app connects to no engine when it starts
  bool byHand;

  /// Kept in memory only when false (tests)
  final bool store;

  /// The local engine plays generated darts instead of detecting them, for trying the app
  bool simulate;

  /// With simulated darts: stream the real cameras all the same; off for trying the app without them
  bool cameras;

  /// The engine on this device listens on the home network, for phones and tablets to connect to
  bool share = false;

  /// Path of the engine program when the player chose one; found automatically otherwise
  String? executable;

  /// The player stopped reaching the chosen engine for this run of the app and enters darts by hand meanwhile; the
  /// choice itself stays, so the next start reaches the engine again. Not stored.
  bool pausedForNow = false;

  static const _mode = 'engine.mode';
  static const _url = 'engine.url';
  static const _simulate = 'engine.simulate';
  static const _cameras = 'engine.cameras';
  static const _share = 'engine.share';
  static const _executable = 'engine.executable';
  static const _chosen = 'engine.chosen';
  static const _byHand = 'engine.byHand';

  /// [localEngine] says whether an engine program is at hand on this device; it then is the first choice offered.
  static Future<EngineSettings> load({bool localEngine = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_mode);
    return EngineSettings(
        mode: mode == EngineMode.thisDevice.name || (mode == null && localEngine)
            ? EngineMode.thisDevice
            : EngineMode.network,
        url: prefs.getString(_url) ?? EngineConnection.defaultUrl,
        simulate: prefs.getBool(_simulate) ?? false,
        cameras: prefs.getBool(_cameras) ?? true,
        // A stored mode is from before the choice was remembered: that player has chosen already.
        chosen: prefs.getBool(_chosen) ?? mode != null,
        byHand: prefs.getBool(_byHand) ?? false,
      )
      ..executable = prefs.getString(_executable)
      ..share = prefs.getBool(_share) ?? false;
  }

  /// Remembers how the darts are counted: by hand, or with the engine of [mode]
  void choose({required bool byHand}) {
    chosen = true;
    this.byHand = byHand;
    pausedForNow = false;
    notifyListeners();
    save();
  }

  /// Darts by hand until the player tries the chosen engine again or the app starts anew
  void pauseForNow() {
    pausedForNow = true;
    notifyListeners();
  }

  /// Trying the chosen engine again ends a pause
  void resume() {
    if (!pausedForNow) return;
    pausedForNow = false;
    notifyListeners();
  }

  Future<void> save() async {
    if (!store) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chosen, chosen);
    await prefs.setBool(_byHand, byHand);
    await prefs.setString(_mode, mode.name);
    await prefs.setString(_url, url);
    await prefs.setBool(_simulate, simulate);
    await prefs.setBool(_cameras, cameras);
    await prefs.setBool(_share, share);
    final program = executable;
    program == null ? await prefs.remove(_executable) : await prefs.setString(_executable, program);
  }
}

/// Starts the engine on this device and connects to it.
Future<void> startLocalEngine(EngineManager manager, EngineConnection connection, EngineSettings settings) async {
  await connection.disconnect();
  manager.executable = settings.executable;
  final url = await manager.start(simulate: settings.simulate, cameras: settings.cameras, share: settings.share);
  if (url != null) await connection.connect(url);
}

/// Connects to the engine the player chose: starts the one on this device, or reaches the one in the network.
Future<void> connectChosenEngine(EngineSettings settings, EngineConnection connection, EngineManager? manager) async {
  settings.resume();
  if (settings.mode == EngineMode.thisDevice && manager != null) {
    await startLocalEngine(manager, connection, settings);
  } else {
    await connection.connect(settings.url);
  }
}

/// The engine on this device is on its way up as the chosen way of counting: not reachable yet, but not out of reach
bool chosenLocalEngineStarting(EngineSettings? settings, EngineManager? manager) =>
    settings != null &&
    settings.chosen &&
    !settings.byHand &&
    settings.mode == EngineMode.thisDevice &&
    manager?.state == LocalEngineState.starting;

/// How the darts are counted, on every platform; the app follows a change of the choice
class EngineSettingsScope extends InheritedNotifier<EngineSettings> {
  const EngineSettingsScope({super.key, required EngineSettings settings, required super.child})
    : super(notifier: settings);

  static EngineSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EngineSettingsScope>()!.notifier!;

  static EngineSettings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EngineSettingsScope>()?.notifier;
}

/// The engine on this device and the remembered choice, for the engine card; absent where no engine can run locally.
class LocalEngineScope extends InheritedNotifier<EngineManager> {
  const LocalEngineScope({super.key, required EngineManager manager, required this.settings, required super.child})
    : super(notifier: manager);

  final EngineSettings settings;

  static LocalEngineScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocalEngineScope>();
}
