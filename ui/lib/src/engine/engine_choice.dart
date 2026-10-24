// Which engine the app uses (#105): its own on this device, or one in the network; remembered between starts.
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'engine_connection.dart';
import 'engine_manager.dart';

enum EngineMode { thisDevice, network }

/// The player's last choice, stored on the device
class EngineSettings {
  EngineSettings({this.mode = EngineMode.network, this.url = EngineConnection.defaultUrl, this.cameras = true});

  EngineMode mode;
  String url;

  /// The local engine streams the real cameras; off for trying the app without them
  bool cameras;

  /// Path of the engine program when the player chose one; found automatically otherwise
  String? executable;

  static const _mode = 'engine.mode';
  static const _url = 'engine.url';
  static const _cameras = 'engine.cameras';
  static const _executable = 'engine.executable';

  static Future<EngineSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return EngineSettings(
      mode: prefs.getString(_mode) == EngineMode.thisDevice.name ? EngineMode.thisDevice : EngineMode.network,
      url: prefs.getString(_url) ?? EngineConnection.defaultUrl,
      cameras: prefs.getBool(_cameras) ?? true,
    )..executable = prefs.getString(_executable);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mode, mode.name);
    await prefs.setString(_url, url);
    await prefs.setBool(_cameras, cameras);
    final program = executable;
    program == null ? await prefs.remove(_executable) : await prefs.setString(_executable, program);
  }
}

/// Starts the engine on this device and connects to it.
Future<void> startLocalEngine(EngineManager manager, EngineConnection connection, EngineSettings settings) async {
  await connection.disconnect();
  manager.executable = settings.executable;
  final url = await manager.start(cameras: settings.cameras);
  if (url != null) await connection.connect(url);
}

/// The engine on this device and the remembered choice, for the engine card; absent where no engine can run locally.
class LocalEngineScope extends InheritedNotifier<EngineManager> {
  const LocalEngineScope({super.key, required EngineManager manager, required this.settings, required super.child})
    : super(notifier: manager);

  final EngineSettings settings;

  static LocalEngineScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocalEngineScope>();
}
