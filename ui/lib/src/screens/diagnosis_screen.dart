import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import '../../l10n/app_localizations.dart';
import '../engine/camera_order.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import '../engine/engine_errors.dart';

/// The live setup diagnosis (#137): the engine watches the cameras while the player follows the steps (empty board,
/// one dart in, pull it, …) and lists what is wrong with the setup, each finding with what to do about it.
class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({super.key});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  String? _error;

  /// The error came from stopping, not starting
  bool _stopFailed = false;
  bool _busy = false;

  Future<void> _request(Future<String?> Function() request, {required bool stop}) async {
    setState(() => _busy = true);
    final error = await request();
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
        _stopFailed = stop;
      });
    }
  }

  Future<void> _start() => _request(EngineScope.of(context).startDiagnosis, stop: false);

  Future<void> _stop() => _request(EngineScope.of(context).stopDiagnosis, stop: true);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = EngineScope.of(context);
    final diagnosis = engine.diagnosis;
    final running = diagnosis?.running ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.diagnosis),
        actions: [
          if (engine.isConnected)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: running
                  ? OutlinedButton.icon(
                      key: const ValueKey('diagnosis-stop'),
                      onPressed: _busy ? null : _stop,
                      icon: const Icon(Icons.stop),
                      label: Text(l10n.stopDiagnosis),
                    )
                  : FilledButton.icon(
                      key: const ValueKey('diagnosis-start'),
                      onPressed: _busy ? null : _start,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(diagnosis == null ? l10n.startDiagnosis : l10n.restartDiagnosis),
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
              if (!engine.isConnected) Text(l10n.diagnosisNeedsEngine),
              if (_error != null)
                Text(
                  _error == 'not_available'
                      ? l10n.diagnosisNotAvailable
                      : engineErrorText(l10n, _error!) ??
                            (_stopFailed ? l10n.diagnosisStopFailed(_error!) : l10n.diagnosisFailed(_error!)),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (diagnosis == null && engine.isConnected && _error == null) Text(l10n.diagnosisIntro),
              if (diagnosis != null) ...[
                if (diagnosis.running)
                  _StepCard(diagnosis: diagnosis, onFinish: _stop)
                else if (diagnosis.periods.isNotEmpty)
                  _ResultCard(diagnosis: diagnosis),
                const SizedBox(height: 16),
                Text(l10n.diagnosisFindings, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (diagnosis.findings.isEmpty) Text(l10n.diagnosisNoFindings),
                for (final finding in diagnosis.findings) _FindingTile(finding: finding, cameras: diagnosis.cameras),
                if (diagnosis.periods.isNotEmpty) ...[const SizedBox(height: 16), _PeriodsCard(diagnosis: diagnosis)],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// After the diagnosis: one clear verdict, with the findings below it
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.diagnosis});

  final EngineDiagnosis diagnosis;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final problems = diagnosis.findings.where((f) => f.severity == 'problem').length;
    final warnings = diagnosis.findings.where((f) => f.severity == 'warning').length;
    final darts = diagnosis.periods.where((p) => !p.empty).length;
    final (icon, color, title, text) = problems > 0
        ? (Icons.error, theme.colorScheme.error, l10n.resultProblems(problems), l10n.resultFixHint)
        : warnings > 0
        ? (Icons.warning_amber, StatusColors.of(context).warning, l10n.resultWarnings(warnings), l10n.resultFixHint)
        : (Icons.check_circle, StatusColors.of(context).good, l10n.resultAllGood, l10n.resultAllGoodHint);
    return Card(
      key: const ValueKey('diagnosis-result'),
      color: color.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.diagnosisFinished, style: theme.textTheme.labelLarge),
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(text),
                  if (darts < diagnosisDarts) ...[
                    const SizedBox(height: 4),
                    Text(l10n.resultFewDarts(darts, diagnosisDarts), style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The player's name of a camera of the diagnosis, or "Kamera N" in the player's order; the id where it is not one of
/// them
String cameraName(BuildContext context, List<String> cameras, String id) =>
    CameraOrderScope.of(context).label(AppLocalizations.of(context), cameras, id);

/// Darts the diagnosis needs for findings that hold (docs/setup-diagnosis.md: 8 to 10 places)
const int diagnosisDarts = 8;

class _StepCard extends StatelessWidget {
  const _StepCard({required this.diagnosis, required this.onFinish});

  final EngineDiagnosis diagnosis;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (icon, instruction) = switch (diagnosis.step) {
      'empty_board' => (Icons.crop_free, l10n.stepEmptyBoard),
      'remove_darts' => (Icons.back_hand, l10n.stepRemoveDarts),
      'insert_dart' => (Icons.ads_click, l10n.stepInsertDart),
      'remove_dart' => (Icons.back_hand, l10n.stepRemoveDart),
      _ => (Icons.help_outline, diagnosis.step),
    };
    final (stateText, stateColor) = switch (diagnosis.state) {
      'moving' => (l10n.diagnosisMoving, StatusColors.of(context).warning),
      'settling' => (l10n.diagnosisSettling, StatusColors.of(context).warning),
      'measuring' => (l10n.diagnosisMeasuring, theme.colorScheme.primary),
      'measured' => (l10n.diagnosisMeasured, StatusColors.of(context).good),
      'stopped' => (l10n.diagnosisStopped, theme.disabledColor),
      _ => (diagnosis.state, theme.disabledColor),
    };
    final measuring = diagnosis.state == 'settling' || diagnosis.state == 'measuring';
    final darts = diagnosis.periods.where((p) => !p.empty).length;
    final enough = darts >= diagnosisDarts;
    // Done once enough darts are measured and the last one is out, so the board ends empty as it started.
    final done = enough && diagnosis.step != 'remove_dart';
    final (shownIcon, shownText) = done
        ? (Icons.check_circle, l10n.diagnosisEnough)
        : enough
        ? (Icons.back_hand, l10n.stepRemoveLastDart)
        : (icon, instruction);
    return Card(
      color: done ? StatusColors.of(context).good.withValues(alpha: 0.25) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(shownIcon, size: 40, color: done ? StatusColors.of(context).good : theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(shownText, key: const ValueKey('diagnosis-step'), style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            if (!enough && diagnosis.step == 'insert_dart') ...[
              const SizedBox(height: 4),
              Text(l10n.stepInsertDartHint, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    key: const ValueKey('diagnosis-progress'),
                    value: math.min(1.0, darts / diagnosisDarts),
                    color: enough ? StatusColors.of(context).good : null,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text(l10n.diagnosisProgress(darts, diagnosisDarts)),
              ],
            ),
            if (done) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('diagnosis-finish'),
                onPressed: onFinish,
                icon: const Icon(Icons.done_all),
                label: Text(l10n.finishDiagnosis),
              ),
              const SizedBox(height: 4),
              Text(l10n.diagnosisMoreDartsOptional, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (measuring)
                      const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(Icons.circle, size: 12, color: stateColor),
                    const SizedBox(width: 8),
                    Text(stateText, key: const ValueKey('diagnosis-state')),
                  ],
                ),
                Text(
                  l10n.diagnosisSummary(
                    _duration(diagnosis.elapsedS),
                    diagnosis.periods.where((p) => p.empty).length,
                    diagnosis.periods.where((p) => !p.empty).length,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _duration(double seconds) {
    final s = seconds.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

class _FindingTile extends StatelessWidget {
  const _FindingTile({required this.finding, required this.cameras});

  final DiagnosisFinding finding;
  final List<String> cameras;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (icon, color) = switch (finding.severity) {
      'problem' => (Icons.error, theme.colorScheme.error),
      'warning' => (Icons.warning_amber, StatusColors.of(context).warning),
      _ => (Icons.info_outline, theme.colorScheme.primary),
    };
    final text = findingText(l10n, finding);
    final camera = finding.camera;
    return Card(
      key: ValueKey('finding-${finding.code}-${camera ?? 'all'}'),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(camera == null ? text.message : '${cameraName(context, cameras, camera)}: ${text.message}'),
        subtitle: text.hint.isEmpty ? null : Text(text.hint),
        isThreeLine: text.hint.length > 60,
      ),
    );
  }
}

/// Message and hint of a finding in the app's language, from its code and values; the engine's English text for
/// codes this app does not know yet.
({String message, String hint}) findingText(AppLocalizations l10n, DiagnosisFinding f) {
  String n(String key, [int decimals = 1]) =>
      NumberFormat.decimalPatternDigits(locale: l10n.localeName, decimalDigits: decimals).format(f.values[key] ?? 0);
  int i(String key) => (f.values[key] ?? 0).round();
  final serious = f.severity != 'info';
  return switch (f.code) {
    'lost_frames' => (message: l10n.findingLostFrames(n('percent')), hint: l10n.hintLostFrames),
    'few_still_moments' => (
      message: l10n.findingFewStillMoments(i('count'), n('seconds', 0)),
      hint: l10n.hintFewStillMoments,
    ),
    'not_empty_at_start' => (message: l10n.findingNotEmptyAtStart, hint: l10n.hintNotEmptyAtStart),
    'no_refinement' => (message: l10n.findingNoRefinement, hint: l10n.hintNoRefinement),
    'board_not_found' => (message: l10n.findingBoardNotFound, hint: l10n.hintBoardNotFound),
    'calibration_off' => (message: l10n.findingCalibrationOff(n('mm', 2)), hint: l10n.hintCalibrationOff),
    'drift' => (message: l10n.findingDrift(n('px', 2), n('minutes')), hint: l10n.hintDrift),
    'exposure_settling' || 'light_changed' => (
      message: l10n.findingLightChanged(n('percent', 0), n('low', 0), n('low_s', 0), n('high', 0), n('high_s', 0)),
      hint: f.code == 'exposure_settling' ? l10n.hintExposureSettling : l10n.hintLightChanged,
    ),
    'board_changed' => (message: l10n.findingBoardChanged(i('count')), hint: l10n.hintBoardChanged),
    'no_darts' => (message: l10n.findingNoDarts, hint: l10n.hintNoDarts),
    'darts_located' => (
      message: l10n.findingDartsLocated(i('located'), i('darts'), i('abstained')),
      hint: serious ? l10n.hintDartsLocated : '',
    ),
    'darts_cut_lost' => (
      message: l10n.findingDartsCutLost(i('cut'), i('darts'), i('lost')),
      hint: l10n.hintDartsCutLost,
    ),
    'darts_cut' => (message: l10n.findingDartsCut(i('cut'), i('darts')), hint: l10n.hintDartsCut),
    'darts_not_seen' => (message: l10n.findingDartsNotSeen(i('missed'), i('darts')), hint: l10n.hintDartsNotSeen),
    'camera_disagrees' => (
      message: l10n.findingCameraDisagrees(i('disagreed'), i('darts')),
      hint: l10n.hintCameraDisagrees,
    ),
    'planes_agree' => (message: l10n.findingPlanesAgree(n('mm', 2)), hint: serious ? l10n.hintPlanesAgree : ''),
    _ => (message: f.message, hint: f.hint),
  };
}

/// The measured still moments, newest first: per camera how it saw the board, and where a dart was located.
class _PeriodsCard extends StatelessWidget {
  const _PeriodsCard({required this.diagnosis});

  final EngineDiagnosis diagnosis;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPatternDigits(locale: l10n.localeName, decimalDigits: 1);
    String camera(int index, DiagnosisPeriodCamera c) {
      final parts = <String>[
        if (c.dart != null)
          switch (c.dart) {
            'seen' => l10n.dartSeen,
            'cut' => l10n.dartCut,
            _ => l10n.dartNotSeen,
          },
        if (c.calibrationMm != null) l10n.periodCalibration(number.format(c.calibrationMm)),
        if (c.brightness != null) l10n.periodBrightness(c.brightness!.round()),
      ];
      // Period cameras are in the order of the diagnosis' camera list.
      final name = index < diagnosis.cameras.length
          ? cameraName(context, diagnosis.cameras, diagnosis.cameras[index])
          : l10n.cameraNumber(index + 1);
      return '$name: ${parts.join(', ')}';
    }

    return ExpansionTile(
      key: const ValueKey('diagnosis-periods'),
      tilePadding: EdgeInsets.zero,
      title: Text(l10n.diagnosisPeriods(diagnosis.periods.length), style: theme.textTheme.titleMedium),
      children: [
        for (final period in diagnosis.periods.reversed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(period.empty ? Icons.crop_free : Icons.ads_click),
            title: Text(
              [
                l10n.secondsRange(period.startS.round(), period.endS.round()),
                period.empty
                    ? l10n.periodEmpty
                    : period.boardMm == null
                    ? l10n.periodDartNotLocated
                    : l10n.periodDartLocated(
                        number.format(period.boardMm![0]),
                        number.format(period.boardMm![1]),
                        period.agreeingCameras.length,
                        number.format(period.worstPlaneMm ?? 0),
                      ),
              ].join('  ·  '),
            ),
            subtitle: Text([for (var c = 0; c < period.cameras.length; ++c) camera(c, period.cameras[c])].join('\n')),
          ),
      ],
    );
  }
}
