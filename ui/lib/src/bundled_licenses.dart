import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The fonts the app bundles (assets/fonts) and where their licence is
const bundledFonts = {
  'Barlow Condensed': 'assets/fonts/barlow-condensed/OFL.txt',
  'Inter': 'assets/fonts/inter/OFL.txt',
};

/// One entry per bundled font, with its licence from the app's assets
Stream<LicenseEntry> fontLicenses(AssetBundle bundle) async* {
  for (final MapEntry(key: name, value: path) in bundledFonts.entries) {
    yield LicenseEntryWithLineBreaks([name], await bundle.loadString(path));
  }
}

/// The licences of the bundled fonts, and of native third-party code packed next to the app (the engine's OpenCV, IXWebSocket and libraries on
/// Linux, the Visual C++ runtime on Windows), so the licence page lists them beside the Dart packages.
///
/// The release packaging puts them in `licenses/<component>/<files>` next to the app's program; a development build
/// has no such folder and adds nothing.
void registerBundledLicenses() {
  LicenseRegistry.addLicense(() => fontLicenses(rootBundle));
  if (kIsWeb) return;
  final dir = Directory('${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}licenses');
  LicenseRegistry.addLicense(() => bundledLicenses(dir));
}

/// One entry per component folder in [dir], its files' texts in name order.
Stream<LicenseEntry> bundledLicenses(Directory dir) async* {
  if (!await dir.exists()) return;
  final components = await dir.list().where((e) => e is Directory).cast<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final component in components) {
    final files = await component.list().where((e) => e is File).cast<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final texts = <String>[];
    for (final file in files) {
      try {
        texts.add(await file.readAsString());
      } on FileSystemException {
        // A file that is not text cannot be shown; the others still are.
      } on FormatException {
        // Not UTF-8.
      }
    }
    if (texts.isEmpty) continue;
    final name = component.uri.pathSegments.where((s) => s.isNotEmpty).last;
    yield LicenseEntryWithLineBreaks([name], texts.join('\n\n'));
  }
}
