import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../board/dartboard.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import '../theme.dart';
import '../engine/engine_errors.dart';

/// The guided reference measurement (#14): one dart after the other is pushed by hand into a known position, and the
/// error of the located point shows how accurate the whole chain from calibration to tip is.
class ReferenceRunScreen extends StatefulWidget {
  const ReferenceRunScreen({super.key});

  @override
  State<ReferenceRunScreen> createState() => _ReferenceRunScreenState();
}

/// Errors up to this are good, up to [fairMm] usable (provisional, like the diagnosis thresholds)
const double goodMm = 1.0;
const double fairMm = 2.5;

class _ReferenceRunScreenState extends State<ReferenceRunScreen> {
  String? _error;

  Future<void> _run(Future<String?> Function() request) async {
    final error = await request();
    if (mounted) setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = EngineScope.of(context);
    final run = engine.referenceRun;
    final running = run?.running ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.referenceRun),
        actions: [
          if (engine.isConnected)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: running
                  ? OutlinedButton.icon(
                      key: const ValueKey('reference-stop'),
                      onPressed: () => _run(engine.stopReferenceRun),
                      icon: const Icon(Icons.stop),
                      label: Text(l10n.stopDiagnosis),
                    )
                  : FilledButton.icon(
                      key: const ValueKey('reference-start'),
                      onPressed: () => _run(engine.startReferenceRun),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(run == null ? l10n.startDiagnosis : l10n.restartDiagnosis),
                    ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Text(
                  _error == 'not_calibrated'
                      ? l10n.referenceNotCalibrated
                      : engineErrorText(l10n, _error!) ?? l10n.calibErrorOther(_error!),
                  style: TextStyle(color: StatusColors.of(context).bad),
                ),
              if (run == null) Text(l10n.referenceIntro),
              if (run != null) ...[
                if (run.step == 'done')
                  _Verdict(run: run)
                else if (!run.running)
                  _Stopped(run: run)
                else
                  _TargetCard(run: run),
                const SizedBox(height: 16),
                _MarkedBoard(run: run),
                if (run.results.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(l10n.referenceResults, style: Theme.of(context).textTheme.titleMedium),
                  for (final r in run.results.reversed) _ResultTile(result: r),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _mm(AppLocalizations l10n, double value) =>
    NumberFormat.decimalPatternDigits(locale: l10n.localeName, decimalDigits: 1).format(value);

/// The error as it is shown, to one decimal, so a dart shown as 1.0 mm is not coloured as more than 1 mm
double _shown(double errorMm) => (errorMm * 10).round() / 10;

Color _errorColor(BuildContext context, double? error) {
  final status = StatusColors.of(context);
  if (error == null) return status.warning;
  final errorMm = _shown(error);
  return errorMm <= goodMm
      ? status.good
      : errorMm <= fairMm
      ? status.warning
      : status.bad;
}

/// What to do with the next dart, with the target magnified
class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.run});

  final ReferenceRun run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final target = run.target;
    final (icon, text) = switch (run.step) {
      'empty_board' => (Icons.crop_free, l10n.stepEmptyBoard),
      'remove_dart' => (Icons.back_hand, l10n.stepRemoveDart),
      _ when target == null => (Icons.hourglass_empty, l10n.referenceWaiting),
      _ when target.hintCode == 'bull_centre' => (Icons.ads_click, l10n.referenceBullCentre),
      _ when target.wires.length == 2 => (
        Icons.ads_click,
        l10n.referenceCorner(target.field, target.wires.first, target.wires.last),
      ),
      _ => (Icons.ads_click, target.field),
    };
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (target != null)
          Text(l10n.referenceProgress(target.index + 1, target.total), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, key: const ValueKey('reference-instruction'), style: theme.textTheme.titleLarge),
            ),
          ],
        ),
        if (run.step == 'insert_dart' && target?.hintCode == 'corner') ...[
          const SizedBox(height: 8),
          Text(l10n.referenceCornerHint, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: target == null ? 1 : run.results.length / target.total,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        // On a phone the zoom goes below the instruction, which keeps the width to read
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 500
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    info,
                    if (target != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: _Zoom(run: run, target: target.boardMm),
                      ),
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: info),
                    if (target != null) ...[const SizedBox(width: 16), _Zoom(run: run, target: target.boardMm)],
                  ],
                ),
        ),
      ),
    );
  }
}

/// The board around the target, magnified: corners are only millimetres apart.
class _Zoom extends StatelessWidget {
  const _Zoom({required this.run, required this.target});

  final ReferenceRun run;
  final BoardPoint target;

  static const double size = 160;
  static const double boardPx = 1400;

  @override
  Widget build(BuildContext context) {
    final engine = EngineScope.of(context);
    final scale = Dartboard.scaleFor(const Size(boardPx, boardPx), engine.geometry, image: engine.boardImage);
    final x = boardPx / 2 + target.xMm * scale;
    final y = boardPx / 2 - target.yMm * scale;
    return ClipRRect(
      key: const ValueKey('reference-zoom'),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: size / 2 - x,
              top: size / 2 - y,
              width: boardPx,
              height: boardPx,
              child: _BoardWithMarks(run: run, markScale: 3),
            ),
          ],
        ),
      ),
    );
  }
}

/// The whole board with the target and every result
class _MarkedBoard extends StatelessWidget {
  const _MarkedBoard({required this.run});

  final ReferenceRun run;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: AspectRatio(aspectRatio: 1, child: _BoardWithMarks(run: run)),
    ),
  );
}

class _BoardWithMarks extends StatelessWidget {
  const _BoardWithMarks({required this.run, this.markScale = 1});

  final ReferenceRun run;
  final double markScale;

  @override
  Widget build(BuildContext context) {
    final engine = EngineScope.of(context);
    final status = StatusColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          fit: StackFit.expand,
          children: [
            Dartboard(geometry: engine.geometry, image: engine.boardImage),
            IgnorePointer(
              child: CustomPaint(
                painter: _MarksPainter(
                  run: run,
                  scale: Dartboard.scaleFor(size, engine.geometry, image: engine.boardImage),
                  markScale: markScale,
                  target: AppColors.accent,
                  good: status.good,
                  warning: status.warning,
                  bad: status.bad,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MarksPainter extends CustomPainter {
  _MarksPainter({
    required this.run,
    required this.scale,
    required this.markScale,
    required this.target,
    required this.good,
    required this.warning,
    required this.bad,
  });

  final ReferenceRun run;
  final double scale;
  final double markScale;
  final Color target, good, warning, bad;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    Offset at(BoardPoint p) => centre + Offset(p.xMm * scale, -p.yMm * scale);
    final r = 4.0 * markScale;
    for (final result in run.results) {
      final expected = at(result.boardMm);
      final located = result.locatedMm;
      final error = result.errorMm == null ? null : _shown(result.errorMm!);
      final colour = error == null
          ? warning
          : error <= goodMm
          ? good
          : error <= fairMm
          ? warning
          : bad;
      canvas.drawCircle(expected, r, Paint()..color = Colors.white.withValues(alpha: 0.7));
      if (located == null) continue;
      canvas.drawLine(
        expected,
        at(located),
        Paint()
          ..color = colour
          ..strokeWidth = 1.5 * markScale,
      );
      canvas.drawCircle(at(located), r, Paint()..color = colour);
    }
    final next = run.target;
    if (next != null && run.running) {
      final p = at(next.boardMm);
      final ring = Paint()
        ..color = target
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * markScale;
      canvas.drawCircle(p, 3 * r, ring);
      canvas.drawLine(p - Offset(5 * r, 0), p - Offset(2 * r, 0), ring);
      canvas.drawLine(p + Offset(2 * r, 0), p + Offset(5 * r, 0), ring);
      canvas.drawLine(p - Offset(0, 5 * r), p - Offset(0, 2 * r), ring);
      canvas.drawLine(p + Offset(0, 2 * r), p + Offset(0, 5 * r), ring);
    }
  }

  @override
  bool shouldRepaint(_MarksPainter old) => old.run != run || old.scale != scale;
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final ReferenceResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = result.errorMm;
    return ListTile(
      key: ValueKey('reference-result-${result.index}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: _errorColor(context, error),
        child: Text('${result.index + 1}', style: const TextStyle(color: AppColors.background, fontSize: 12)),
      ),
      title: Text(error == null ? l10n.referenceAbstained : l10n.referenceError(_mm(l10n, error))),
      subtitle: Text(
        error == null
            ? switch (result.reason) {
                'cameras_disagree' => l10n.referenceCamerasDisagree,
                'seen_by_one_camera' => l10n.referenceSeenByOneCamera,
                _ => result.reason ?? '',
              }
            : l10n.referenceCamerasUsed(result.camerasUsed),
      ),
    );
  }
}

/// A run the player stopped before the last dart: too few darts for a verdict
class _Stopped extends StatelessWidget {
  const _Stopped({required this.run});

  final ReferenceRun run;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('reference-stopped'),
      child: ListTile(
        leading: const Icon(Icons.stop_circle_outlined, size: 36),
        title: Text(AppLocalizations.of(context).referenceStopped(run.results.length)),
      ),
    );
  }
}

/// After the last dart: the figures and one verdict
class _Verdict extends StatelessWidget {
  const _Verdict({required this.run});

  final ReferenceRun run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final summary = run.summary;
    final median = summary?.medianErrorMm;
    final worst = summary?.maxErrorMm;
    final good = median != null && median <= goodMm && (worst ?? 0) <= fairMm && (summary?.abstained ?? 0) <= 1;
    final colour = summary == null || median == null
        ? StatusColors.of(context).warning
        : good
        ? StatusColors.of(context).good
        : median <= fairMm
        ? StatusColors.of(context).warning
        : StatusColors.of(context).bad;
    final figures = summary == null
        ? <(String, String)>[]
        : [
            (l10n.referenceLocated, l10n.countOf(summary.located, summary.located + summary.abstained)),
            (l10n.referenceMedian, median == null ? '–' : l10n.mmValue(_mm(l10n, median))),
            (l10n.referenceP90, summary.p90ErrorMm == null ? '–' : l10n.mmValue(_mm(l10n, summary.p90ErrorMm!))),
            (l10n.referenceMax, worst == null ? '–' : l10n.mmValue(_mm(l10n, worst))),
          ];
    return Card(
      key: const ValueKey('reference-verdict'),
      color: colour.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(good ? Icons.verified : Icons.warning_amber, size: 40, color: colour),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(good ? l10n.referenceGood : l10n.referenceNotGood, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                for (final (label, value) in figures)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.bodySmall),
                      Text(value, key: ValueKey('reference-figure-$label'), style: theme.textTheme.titleMedium),
                    ],
                  ),
              ],
            ),
            if (!good) ...[const SizedBox(height: 8), Text(l10n.referenceNotGoodHint)],
          ],
        ),
      ),
    );
  }
}
