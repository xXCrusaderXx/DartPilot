import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../l10n/app_localizations.dart';
import '../engine/camera_order.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import '../theme.dart';
import '../widgets/overlay_preview.dart';
import '../engine/engine_errors.dart';
import 'diagnosis_screen.dart';

enum CalibrationStep { overview, light, board, refine, done }

/// The calibration wizard (docs/engine-api.md, "Calibration"): light, the board of every camera, refinement. The
/// player works step by step, one camera after the other; the engine computes and stores.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key, this.startCamera});

  /// Opens the board step of this camera directly, e.g. when the check found it moved
  final String? startCamera;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  late CalibrationStep _step = widget.startCamera == null ? CalibrationStep.overview : CalibrationStep.board;

  /// Camera of the board step, by id: the engine's camera list can change while the wizard is open
  late String? _camera = widget.startCamera;

  /// Error code of the last request, shown until the next one
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<String?> Function() request) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await request();
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  void _go(CalibrationStep step) => setState(() {
    _step = step;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = EngineScope.of(context);
    final cameras = orderedCameras(context);
    final index = math.max(0, cameras.indexOf(_camera ?? ''));
    final steps = [
      (CalibrationStep.light, l10n.calibStepLight),
      (CalibrationStep.board, l10n.calibStepBoard),
      (CalibrationStep.refine, l10n.calibStepRefine),
      (CalibrationStep.done, l10n.calibStepDone),
    ];
    final Widget body = !engine.isConnected || engine.calibration == null || cameras.isEmpty
        ? Text(l10n.calibNeedsCameras)
        : switch (_step) {
            CalibrationStep.overview => _Overview(cameras: cameras, onStart: () => _go(CalibrationStep.light)),
            CalibrationStep.light => _LightStep(
              busy: _busy,
              error: _error,
              onTune: () => _run(engine.tuneWhiteBalance),
              onNext: () => _go(CalibrationStep.board),
            ),
            CalibrationStep.board => _BoardStep(
              key: ValueKey('board-${cameras[index]}'),
              camera: cameras[index],
              number: index + 1,
              count: cameras.length,
              busy: _busy,
              error: _error,
              onDetect: () => _run(() => engine.detectBoard(cameras[index])),
              onTap: (point) => _run(() => engine.setSector20(cameras[index], point)),
              onNext: () => index + 1 < cameras.length
                  ? setState(() {
                      _camera = cameras[index + 1];
                      _error = null;
                    })
                  : _go(CalibrationStep.refine),
            ),
            CalibrationStep.refine => _RefineStep(
              busy: _busy,
              error: _error,
              onRefine: () => _run(engine.refineCameras),
              onMeasureAgain: (camera) => setState(() {
                _camera = camera;
                _step = CalibrationStep.board;
                _error = null;
              }),
              onNext: () => _go(CalibrationStep.done),
            ),
            CalibrationStep.done => _DoneStep(onClose: () => Navigator.of(context).pop()),
          };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.calibration)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_step != CalibrationStep.overview) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, (step, label)) in steps.indexed)
                      ChoiceChip(
                        key: ValueKey('calib-step-${step.name}'),
                        label: Text('${i + 1}. $label'),
                        selected: _step == step,
                        onSelected: _busy ? null : (_) => _go(step),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              body,
            ],
          ),
        ),
      ),
    );
  }
}

String _mm(AppLocalizations l10n, double value) =>
    NumberFormat.decimalPatternDigits(locale: l10n.localeName, decimalDigits: 2).format(value);

/// What is calibrated, per camera, and the way in
class _Overview extends StatelessWidget {
  const _Overview({required this.cameras, required this.onStart});

  final List<String> cameras;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = EngineScope.of(context).calibration!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.calibIntro),
        const SizedBox(height: 16),
        if (status.refinementStale)
          Card(
            color: StatusColors.of(context).warning.withValues(alpha: 0.15),
            child: ListTile(leading: const Icon(Icons.update), title: Text(l10n.calibStale)),
          ),
        for (final camera in cameras)
          Builder(
            builder: (context) {
              final c = status.of(camera);
              return Card(
                child: ListTile(
                  key: ValueKey('calib-overview-$camera'),
                  leading: Icon(
                    c?.refined == true ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: c?.refined == true ? StatusColors.of(context).good : theme.disabledColor,
                  ),
                  title: Text(cameraLabel(context, camera)),
                  subtitle: Text(
                    [
                      c?.boardPlaneMm == null
                          ? l10n.calibBoardMissing
                          : l10n.calibBoardMeasured(_mm(l10n, c!.boardPlaneMm!)),
                      if (c?.whiteBalanceKelvin != null) '${c!.whiteBalanceKelvin} K',
                      c?.intrinsics == 'valid' ? l10n.calibLensOwn : l10n.calibLensNone,
                    ].join('  ·  '),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('calib-start'),
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.calibStart),
        ),
      ],
    );
  }
}

class _Instruction extends StatelessWidget {
  const _Instruction({required this.icon, required this.text, this.hint});

  final IconData icon;
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 36, color: theme.colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, key: const ValueKey('calib-instruction'), style: theme.textTheme.titleLarge),
              if (hint != null) ...[const SizedBox(height: 4), Text(hint!, style: theme.textTheme.bodySmall)],
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.code);

  final String? code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final code = this.code;
    if (code == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        switch (code) {
          'no_detection' => l10n.calibErrorNoDetection,
          'outside_board' => l10n.calibErrorOutsideBoard,
          'fit_failed' => l10n.calibErrorFitFailed,
          'no_board_planes' => l10n.calibErrorNoBoardPlanes,
          'pose_failed' => l10n.calibErrorPoseFailed,
          'save_failed' => l10n.calibErrorSaveFailed,
          _ => engineErrorText(l10n, code) ?? l10n.calibErrorOther(code),
        },
        key: const ValueKey('calib-error'),
        style: TextStyle(color: StatusColors.of(context).bad),
      ),
    );
  }
}

/// Step 1: the white balance for the player's light; board detection depends on it.
class _LightStep extends StatelessWidget {
  const _LightStep({required this.busy, required this.error, required this.onTune, required this.onNext});

  final bool busy;
  final String? error;
  final VoidCallback onTune;
  final VoidCallback onNext;

  static const int minKelvin = 2800;
  static const int maxKelvin = 6400;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = EngineScope.of(context);
    final cameras = orderedCameras(context);
    final state = engine.whiteBalance;
    final running = state?.running ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Instruction(icon: Icons.light_mode, text: l10n.calibLightInstruction, hint: l10n.calibLightHint),
        const SizedBox(height: 16),
        if (state != null)
          Text(switch (state.state) {
            'settling' => l10n.calibLightSettling((state.settleS ?? 0).ceil()),
            'sweeping' => l10n.calibLightSweeping(state.kelvinNow ?? 0),
            'done' => l10n.calibLightDone,
            _ => l10n.calibLightFailed,
          }, key: const ValueKey('calib-light-state')),
        const SizedBox(height: 8),
        for (final camera in cameras)
          _KelvinBar(
            label: cameraLabel(context, camera),
            camera: state?.cameras.where((c) => c.camera == camera).firstOrNull,
            stored: engine.calibration?.of(camera)?.whiteBalanceKelvin,
          ),
        _ErrorText(error),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('calib-light-tune'),
              onPressed: busy || running ? null : onTune,
              icon: running
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.tune),
              label: Text(state?.state == 'done' ? l10n.calibLightAgain : l10n.calibLightTune),
            ),
            FilledButton(
              key: const ValueKey('calib-next'),
              onPressed: running ? null : onNext,
              child: Text(l10n.calibNext),
            ),
          ],
        ),
      ],
    );
  }
}

/// 2800–6400 K for one camera: where the board was found during the sweep, and the chosen value
class _KelvinBar extends StatelessWidget {
  const _KelvinBar({required this.label, required this.camera, required this.stored});

  final String label;
  final CameraWhiteBalance? camera;
  final int? stored;

  /// The bar in words: the range of colour temperatures the board was found in
  String _foundText(AppLocalizations l10n) {
    final found = [
      for (final e in (camera?.foundAt ?? const <int, bool>{}).entries)
        if (e.value) e.key,
    ]..sort();
    return found.isEmpty ? l10n.calibLightNoneFound : l10n.calibLightFoundRange(found.first, found.last);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = StatusColors.of(context);
    final chosen = camera?.chosenKelvin ?? stored;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // A long camera name is cut, not wrapped, so every bar keeps its height
          SizedBox(width: 90, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(
            child: Semantics(
              label: _foundText(l10n),
              child: SizedBox(
                height: 18,
                child: CustomPaint(
                  painter: _KelvinPainter(
                    found: camera?.foundAt ?? const {},
                    chosen: chosen,
                    good: status.good,
                    bad: status.bad.withValues(alpha: 0.5),
                    track: Theme.of(context).colorScheme.outline,
                    marker: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              camera?.code == 'board_not_found_at_any'
                  ? l10n.calibLightNotFound
                  : chosen == null
                  ? '–'
                  : '$chosen K',
              key: ValueKey('calib-kelvin-$label'),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _KelvinPainter extends CustomPainter {
  _KelvinPainter({
    required this.found,
    required this.chosen,
    required this.good,
    required this.bad,
    required this.track,
    required this.marker,
  });

  final Map<int, bool> found;
  final int? chosen;
  final Color good, bad, track, marker;

  double _x(int kelvin, Size size) =>
      (kelvin - _LightStep.minKelvin) / (_LightStep.maxKelvin - _LightStep.minKelvin) * size.width;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = track
        ..strokeWidth = 4,
    );
    // Each tried value covers its 200 K step.
    final step = size.width * 200 / (_LightStep.maxKelvin - _LightStep.minKelvin);
    for (final MapEntry(key: kelvin, value: ok) in found.entries) {
      final x = _x(kelvin, size);
      canvas.drawRect(Rect.fromLTWH(x - step / 2, y - 5, step, 10), Paint()..color = ok ? good : bad);
    }
    final c = chosen;
    if (c != null) {
      final x = _x(c, size);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = marker
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_KelvinPainter old) => old.found != found || old.chosen != chosen;
}

/// Step 2, per camera: detect the board, tap the sector 20, check the numbers.
class _BoardStep extends StatelessWidget {
  const _BoardStep({
    super.key,
    required this.camera,
    required this.number,
    required this.count,
    required this.busy,
    required this.error,
    required this.onDetect,
    required this.onTap,
    required this.onNext,
  });

  final String camera;
  final int number;
  final int count;
  final bool busy;
  final String? error;
  final VoidCallback onDetect;
  final ValueChanged<Offset> onTap;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = StatusColors.of(context);
    final engine = EngineScope.of(context);
    final detection = engine.boardDetections[camera];
    final plane = engine.boardPlanes[camera];
    final found = detection?.ok ?? false;
    final (icon, text, hint) = plane != null
        ? (Icons.fact_check, l10n.calibBoardCheck, l10n.calibBoardCheckHint)
        : found
        ? (Icons.touch_app, l10n.calibBoardTap20, l10n.calibBoardTap20Hint)
        : (Icons.crop_free, l10n.calibBoardDetectInstruction, l10n.calibBoardDetectHint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.calibCameraOf(number, count), style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        _Instruction(icon: icon, text: text, hint: hint),
        const SizedBox(height: 12),
        OverlayPreview(
          camera: camera,
          imageSizePx: detection?.imageSizePx,
          maxFps: 5,
          maxWidth: 1280,
          repaintKey: (detection, plane),
          onTapImagePx: found && !busy ? onTap : null,
          paint: (canvas, size, scale) => _paintBoard(canvas, scale, detection, plane, theme, status),
        ),
        if (detection != null && !found)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.calibBoardNotFound, style: TextStyle(color: status.bad)),
          ),
        if (plane != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.calibBoardFit(_mm(l10n, plane.fitMm), _mm(l10n, plane.worstMm ?? plane.fitMm)),
              key: const ValueKey('calib-board-fit'),
            ),
          ),
        _ErrorText(error),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('calib-detect'),
              onPressed: busy ? null : onDetect,
              icon: busy
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: Text(detection == null ? l10n.calibBoardDetect : l10n.calibBoardDetectAgain),
            ),
            FilledButton(
              key: const ValueKey('calib-next'),
              onPressed: plane == null || busy ? null : onNext,
              child: Text(number < count ? l10n.calibNumbersMatchNext : l10n.calibNumbersMatchRefine),
            ),
          ],
        ),
      ],
    );
  }

  static void _paintBoard(
    Canvas canvas,
    double scale,
    BoardDetection? detection,
    BoardPlaneResult? plane,
    ThemeData theme,
    StatusColors status,
  ) {
    if (detection == null || !detection.ok) return;
    final line = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final e in detection.ellipses) {
      canvas.save();
      canvas.translate(e.center.dx * scale, e.center.dy * scale);
      canvas.rotate(e.angleDeg * math.pi / 180);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 2 * e.halfAxes.width * scale,
          height: 2 * e.halfAxes.height * scale,
        ),
        line,
      );
      canvas.restore();
    }
    for (final (a, b) in detection.wiresPx) {
      canvas.drawLine(a * scale, b * scale, line..strokeWidth = 1);
    }
    final dot = Paint()..color = status.good;
    for (final p in detection.pointsPx) {
      canvas.drawCircle(p * scale, 2.5, dot);
    }
    if (plane == null) return;
    for (final MapEntry(key: sector, value: at) in plane.sectors.entries) {
      final twenty = sector == 20;
      final painter = TextPainter(
        text: TextSpan(
          text: '$sector',
          style: TextStyle(
            color: twenty ? AppColors.background : AppColors.text,
            fontSize: twenty ? 15 : 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final centre = at * scale;
      canvas.drawCircle(centre, twenty ? 13 : 10, Paint()..color = twenty ? AppColors.warning : Colors.black87);
      painter.paint(canvas, centre - Offset(painter.width / 2, painter.height / 2));
    }
  }
}

/// Step 3: all cameras refined together, with a verdict per camera
class _RefineStep extends StatelessWidget {
  const _RefineStep({
    required this.busy,
    required this.error,
    required this.onRefine,
    required this.onMeasureAgain,
    required this.onNext,
  });

  final bool busy;
  final String? error;
  final VoidCallback onRefine;
  final ValueChanged<String> onMeasureAgain;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = StatusColors.of(context);
    final engine = EngineScope.of(context);
    final result = engine.refinement;
    final running = busy || result?.state == 'running';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Instruction(icon: Icons.auto_fix_high, text: l10n.calibRefineInstruction, hint: l10n.calibRefineHint),
        const SizedBox(height: 16),
        if (result != null && result.state == 'done') ...[
          for (final c in result.cameras)
            Card(
              key: ValueKey('calib-refined-${c.camera}'),
              child: ListTile(
                leading: Icon(
                  c.quality == 'good' ? Icons.check_circle : Icons.warning_amber,
                  color: switch (c.quality) {
                    'good' => status.good,
                    'fair' => status.warning,
                    _ => status.bad,
                  },
                ),
                title: Text(
                  '${cameraLabel(context, c.camera)} · ${_mm(l10n, c.heldOutMm)} mm  ·  ${switch (c.quality) {
                    'good' => l10n.calibQualityGood,
                    'fair' => l10n.calibQualityFair,
                    _ => l10n.calibQualityPoor,
                  }}',
                ),
                subtitle: Text(
                  [
                    switch (c.lensFrom) {
                      'own' => l10n.calibLensFromOwn,
                      'model' => l10n.calibLensFromModel,
                      _ => l10n.calibLensFromBoard,
                    },
                    if (c.advice == 'detect_again') l10n.calibAdviceDetectAgain,
                    if (c.advice == 'lens_calibration') l10n.calibAdviceLens,
                  ].join('\n'),
                ),
                trailing: c.advice == 'detect_again'
                    ? TextButton(onPressed: () => onMeasureAgain(c.camera), child: Text(l10n.calibMeasureAgain))
                    : null,
              ),
            ),
          if (result.outerBullMm != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.calibMeasuredBoard(_mm(l10n, result.outerBullMm!), _mm(l10n, result.trebleCentreMm ?? 0)),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
        if (result?.state == 'failed') _ErrorText(result!.code ?? 'failed'),
        _ErrorText(error),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('calib-refine'),
              onPressed: running ? null : onRefine,
              icon: running
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_fix_high),
              label: Text(result?.state == 'done' ? l10n.calibRefineAgain : l10n.calibRefine),
            ),
            FilledButton(
              key: const ValueKey('calib-next'),
              onPressed: result?.state == 'done' && !running ? onNext : null,
              child: Text(l10n.calibNext),
            ),
          ],
        ),
      ],
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Instruction(icon: Icons.verified, text: l10n.calibDone, hint: l10n.calibDoneHint),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('calib-diagnosis'),
              onPressed: () =>
                  Navigator.of(context)
                      .pushReplacement(MaterialPageRoute<void>(builder: (_) => const DiagnosisScreen())),
              icon: const Icon(Icons.troubleshoot),
              label: Text(l10n.diagnosis),
            ),
            FilledButton(key: const ValueKey('calib-close'), onPressed: onClose, child: Text(l10n.close)),
          ],
        ),
      ],
    );
  }
}
