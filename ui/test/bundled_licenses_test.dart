import 'dart:io';

import 'package:dartpilot/src/bundled_licenses.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('licenses'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('each component folder becomes one entry with its files in name order', () async {
    Directory('${dir.path}/OpenCV').createSync();
    File('${dir.path}/OpenCV/zlib-LICENSE').writeAsStringSync('zlib text');
    File('${dir.path}/OpenCV/LICENSE').writeAsStringSync('Apache text');
    Directory('${dir.path}/IXWebSocket').createSync();
    File('${dir.path}/IXWebSocket/LICENSE.txt').writeAsStringSync('BSD text');
    File('${dir.path}/stray.txt').writeAsStringSync('not in a component');

    final entries = await bundledLicenses(dir).toList();

    expect(entries.map((e) => e.packages.single), ['IXWebSocket', 'OpenCV']);
    final opencv = entries[1].paragraphs.map((p) => p.text).join('\n');
    expect(opencv.indexOf('Apache text'), lessThan(opencv.indexOf('zlib text')));
  });

  test('no folder, no entries', () async {
    expect(await bundledLicenses(Directory('${dir.path}/missing')).toList(), isEmpty);
  });

  test('a component with only unreadable files is left out', () async {
    Directory('${dir.path}/Binary').createSync();
    File('${dir.path}/Binary/blob').writeAsBytesSync([0xff, 0xfe, 0x00, 0xc3]);

    expect(await bundledLicenses(dir).toList(), isEmpty);
  });
}
