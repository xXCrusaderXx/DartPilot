import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/stats/statistics.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final statistics = Statistics(FileGameStore())..load();
  runApp(DartPilotApp(statistics: statistics));
}
