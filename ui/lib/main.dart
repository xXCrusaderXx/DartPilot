import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/display.dart';
import 'src/engine/camera_order.dart';
import 'src/sound/caller.dart';
import 'src/stats/dart_links.dart';
import 'src/stats/statistics.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final statistics = Statistics(FileGameStore(), PrefsProfileStore())..load();
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
    ),
  );
}
