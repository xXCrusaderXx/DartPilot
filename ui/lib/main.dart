import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/bundled_licenses.dart';
import 'src/display.dart';
import 'src/engine/camera_order.dart';
import 'src/engine/engine_choice.dart';
import 'src/engine/engine_manager.dart';
import 'src/sound/caller.dart';
import 'src/stats/dart_links.dart';
import 'src/stats/prefs_game_store.dart';
import 'src/stats/statistics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledLicenses();
  // Read before the first page, which depends on it: the choice of how darts are counted, or that choice itself.
  final engineSettings = await EngineSettings.load(
    localEngine: EngineManager.supported && findEngineExecutable() != null,
  ).catchError((Object _) => EngineSettings());
  final statistics = Statistics(kIsWeb ? PrefsGameStore() : FileGameStore(), PrefsProfileStore())..load();
  final cameraOrder = CameraOrder(PrefsCameraOrderStore())..load();
  final dartLinks = DartLinks(PrefsDartLinksStore())..load();
  final caller = Caller(SystemVoice())..load();
  final display = DisplaySettings()..load();
  runApp(
    DartPilotApp(
      statistics: statistics,
      cameraOrder: cameraOrder,
      dartLinks: dartLinks,
      caller: caller,
      display: display,
      settings: engineSettings,
    ),
  );
}
