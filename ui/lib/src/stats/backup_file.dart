import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

/// Lets the player pick a backup file and returns its text; null when they picked none. Phones get no filter, as their
/// file managers often do not know a .json file's type.
Future<String?> pickBackupText() async {
  final mobile =
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  final file = await openFile(
    acceptedTypeGroups: [
      if (!mobile) const XTypeGroup(label: 'JSON', extensions: ['json']),
    ],
  );
  return file?.readAsString();
}
