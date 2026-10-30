import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Hands the export to the browser as a download and returns its name.
Future<String> saveExport(String name, String content) async {
  final bytes = utf8.encode(content);
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'text/plain;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  try {
    web.HTMLAnchorElement()
      ..href = url
      ..download = name
      ..click();
  } finally {
    web.URL.revokeObjectURL(url);
  }
  return name;
}
