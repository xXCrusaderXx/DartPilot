import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import '../theme.dart';
import '../widgets/overlay_preview.dart';
import 'calibration_screen.dart';

/// Has a camera moved? Every camera against its calibration, live: where the board's points should be, where they
/// are, and a verdict per camera with the way back into the wizard.
class CalibrationCheckScreen extends StatefulWidget {
  const CalibrationCheckScreen({super.key});

  @override
  State<CalibrationCheckScreen> createState() => _CalibrationCheckScreenState();
}

class _CalibrationCheckScreenState extends State<CalibrationCheckScreen> {
  EngineConnection? _engine;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = EngineScope.of(context);
    if (identical(engine, _engine)) return;
    _engine?.unwatchCalibrationCheck();
    // The engine checks every 2 s for as long as someone watches; leaving the page ends it.
    _engine = engine..watchCalibrationCheck();
  }

  @override
  void dispose() {
    _engine?.unwatchCalibrationCheck();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = EngineScope.of(context);
    final cameras = engine.hello?.cameras ?? const <String>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.calibrationCheck)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 1300 ? 3 : (constraints.maxWidth > 800 ? 2 : 1);
          final width = (constraints.maxWidth - 32 - 12 * (columns - 1)) / columns;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.calibrationCheckIntro),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (i, camera) in cameras.indexed)
                    SizedBox(
                      width: width,
                      child: _CameraCheck(camera: camera, number: i + 1, cameras: cameras),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Colour and wording of a check state
(Color, String) checkVerdict(BuildContext context, CalibrationCheck? check, List<String> cameras) {
  final l10n = AppLocalizations.of(context);
  final status = StatusColors.of(context);
  final mm = check?.mm == null
      ? ''
      : NumberFormat.decimalPatternDigits(locale: l10n.localeName, decimalDigits: 1).format(check!.mm);
  final fits = check?.fitsCamera;
  return switch (check?.state) {
    'ok' => (status.good, l10n.checkOk(mm)),
    'off' => (status.warning, l10n.checkOff(mm)),
    'moved' => (status.bad, l10n.checkMoved(mm)),
    'wrong_port' => (
      status.bad,
      l10n.checkWrongPort(fits == null || !cameras.contains(fits) ? '?' : '${cameras.indexOf(fits) + 1}'),
    ),
    'no_board' => (Theme.of(context).disabledColor, l10n.checkNoBoard),
    'not_calibrated' => (Theme.of(context).disabledColor, l10n.checkNotCalibrated),
    _ => (Theme.of(context).disabledColor, l10n.checkChecking),
  };
}

class _CameraCheck extends StatelessWidget {
  const _CameraCheck({required this.camera, required this.number, required this.cameras});

  final String camera;
  final int number;
  final List<String> cameras;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final engine = EngineScope.of(context);
    final check = engine.calibrationChecks[camera] ?? engine.calibration?.of(camera)?.check;
    final (colour, text) = checkVerdict(context, check, cameras);
    return Card(
      key: ValueKey('check-$camera'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                Icon(Icons.circle, size: 12, color: colour),
                const SizedBox(width: 8),
                Text(l10n.cameraNumber(number), style: theme.textTheme.titleSmall),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(text, key: ValueKey('check-text-$camera')),
          ),
          OverlayPreview(
            camera: camera,
            imageSizePx: check?.imageSizePx,
            maxFps: 2,
            repaintKey: check,
            paint: (canvas, size, scale) => _paintCheck(canvas, scale, check),
          ),
          if (check != null && check.needsCalibration)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: ValueKey('check-recalibrate-$camera'),
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => CalibrationScreen(startCamera: camera))),
                  icon: const Icon(Icons.straighten),
                  label: Text(l10n.calibMeasureAgain),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Blue rings where the calibration expects the points, green dots where they are now, amber lines between
  static void _paintCheck(Canvas canvas, double scale, CalibrationCheck? check) {
    if (check == null) return;
    final ring = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final dot = Paint()..color = AppColors.good;
    final drift = Paint()
      ..color = AppColors.warning
      ..strokeWidth = 1.5;
    for (var i = 0; i < check.expectedPx.length; ++i) {
      final expected = check.expectedPx[i] * scale;
      canvas.drawCircle(expected, 4, ring);
      if (i < check.foundPx.length) {
        final found = check.foundPx[i] * scale;
        canvas.drawLine(expected, found, drift);
        canvas.drawCircle(found, 2.5, dot);
      }
    }
  }
}
