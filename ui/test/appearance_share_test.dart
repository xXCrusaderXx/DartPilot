import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dartboard.dart';
import 'package:dartpilot/src/display.dart';
import 'package:dartpilot/src/screens/x01_panel.dart';
import 'package:dartpilot/src/widgets/appearance_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

DisplaySettings _changed() => DisplaySettings(store: false)
  ..preset = AppearancePreset.light
  ..style = DisplayStyle.scoreboard
  ..brightness = AppBrightness.light
  ..accent = accentSwatches[3]
  ..textSize = TextSize.large
  ..highContrast = true
  ..boardSide = BoardSide.right
  ..boardSize = BoardSize.small
  ..panelDetails = {PanelDetail.checkout, PanelDetail.dartsThrown}
  ..celebration = Celebration.subtle
  ..boardColours = BoardColours.contrast
  ..dartColour = dartSwatches[1]
  ..distance = ViewingDistance.far;

void main() {
  test('a code carries the whole appearance but the viewing distance to another device', () async {
    final code = _changed().toCode();
    expect(code, startsWith(DisplaySettings.codePrefix));
    expect(code, isNot(contains('=')));

    final other = DisplaySettings(store: false)..distance = ViewingDistance.near;
    expect(await other.applyCode('  $code\n'), isTrue);
    expect(other.toCode(), code);
    expect(other.distance, ViewingDistance.near);
    expect(other.accent, accentSwatches[3]);
    expect(other.panelDetails, {PanelDetail.checkout, PanelDetail.dartsThrown});
  });

  test('anything but a code changes nothing', () async {
    final display = _changed();
    final before = display.toCode();
    for (final text in [
      '',
      'hello',
      'ws://192.168.1.2:8765/',
      '${DisplaySettings.codePrefix}!!!',
      '${DisplaySettings.codePrefix}WzFd',
    ]) {
      expect(await display.applyCode(text), isFalse, reason: text);
    }
    expect(display.toCode(), before);
  });

  test('unknown values from a newer app fall back to the defaults, and only offered dart colours are taken', () async {
    final display = _changed();
    const json = '{"textSize":"huge","boardSide":"top","dartColour":4278190335,"details":["visitDarts","sparkles"]}';
    final code = DisplaySettings.codePrefix + base64Url.encode(utf8.encode(json));
    expect(await display.applyCode(code), isTrue);
    expect(display.textSize, TextSize.normal);
    expect(display.boardSide, BoardSide.left);
    expect(display.dartColour, isNull);
    expect(display.panelDetails, {PanelDetail.visitDarts});
    expect(display.accent, isNull);
  });

  testWidgets('the appearance is shared as a QR code and taken over from its code', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final display = DisplaySettings(store: false);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), display: display));
    await playOffline(tester);
    await openSettings(tester);

    await display.set(boardColours: BoardColours.colourSafe);
    await showSettingsEntry(tester, 'appearance-share');
    await tester.tap(find.byKey(const ValueKey('appearance-share')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('appearance-qr')), findsOneWidget);
    final code = tester.widget<SelectableText>(find.byKey(const ValueKey('appearance-code'))).data!;
    expect(code, display.toCode());
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();

    await display.set(boardColours: BoardColours.classic);
    await tester.tap(find.byKey(const ValueKey('appearance-apply')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('appearance-code-field')), 'kein Code');
    await tester.tap(find.byKey(const ValueKey('appearance-code-apply')));
    await tester.pumpAndSettle();
    expect(find.text('Das ist kein Darstellungs-Code von DartPilot'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('appearance-code-field')), code);
    await tester.tap(find.byKey(const ValueKey('appearance-code-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('appearance-code-field')), findsNothing);
    expect(display.boardColours, BoardColours.colourSafe);
  });

  for (final (device, size) in [('a phone upright', Size(412, 915)), ('a monitor', Size(1600, 1000))]) {
    testWidgets('the preview on $device follows the settings beside it', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final display = DisplaySettings(store: false);
      await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), display: display));
      await playOffline(tester);
      await openSettings(tester);
      await showSettingsEntry(tester, 'appearance-preview-open');
      await tester.tap(find.byKey(const ValueKey('appearance-preview-open')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final preview = find.byKey(const ValueKey('appearance-preview'));
      expect(preview, findsOneWidget);
      // The page shows its settings without leading to itself again.
      expect(find.byKey(const ValueKey('appearance-preview-open')), findsNothing);
      Rect board() => tester.getRect(find.descendant(of: preview, matching: find.byType(Dartboard)));
      Rect panel() => tester.getRect(find.descendant(of: preview, matching: find.byType(X01Panel)));
      if (size.width > size.height) {
        expect(board().center.dx, lessThan(panel().center.dx));
        await display.set(boardSide: BoardSide.right);
        await tester.pumpAndSettle();
        expect(board().center.dx, greaterThan(panel().center.dx));
      } else {
        expect(board().center.dy, lessThan(panel().center.dy));
        final before = board().height;
        await display.set(boardSize: BoardSize.small);
        await tester.pumpAndSettle();
        expect(board().height, lessThan(before));
      }
      // The preview's sample game has a checkout route to show or hide.
      expect(find.descendant(of: preview, matching: find.byKey(const ValueKey('checkout'))), findsOneWidget);
      await display.showDetail(PanelDetail.checkout, false);
      await tester.pumpAndSettle();
      expect(find.descendant(of: preview, matching: find.byKey(const ValueKey('checkout'))), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
