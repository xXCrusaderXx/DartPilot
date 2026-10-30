import 'export.dart';

/// Writes the export into the export folder and returns the file's path.
Future<String> saveExport(String name, String content) async => (await writeExport(name, content)).path;
