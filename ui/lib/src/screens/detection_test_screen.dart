import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import '../input/throw_input_panel.dart';
import '../stats/detection_log.dart';
import 'game_layout.dart';

/// The detection test: throw, check what the engine made of the dart, pull, again. Wrong and missed darts are
/// corrected on the board and sent to the engine as corrections, so a recorded session carries them for the replay
/// benchmark. The values of live detection can be changed while it runs.
class DetectionTestScreen extends StatefulWidget {
  const DetectionTestScreen({super.key});

  @override
  State<DetectionTestScreen> createState() => _DetectionTestScreenState();
}

class _DetectionTestScreenState extends State<DetectionTestScreen> {
  EngineConnection? _engine;
  StreamSubscription<EngineEvent>? _subscription;
  DetectionLog? _log;
  LoggedDart? _selected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = EngineScope.of(context);
    if (!identical(engine, _engine)) {
      _subscription?.cancel();
      _engine = engine;
      _log = DetectionLog(geometry: engine.geometry);
      _subscription = engine.events.listen(_onEvent);
      engine.requestDetectionParams();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  DetectionLog get log => _log!;

  void _onEvent(EngineEvent event) {
    if (!mounted) return;
    switch (event) {
      case EngineThrow():
        setState(() => log.detected(event));
      case EngineThrowCorrected(:final throwId, :final action, :final point, :final client):
        if (client == _engine?.clientName) {
          if (action == 'added' && point != null) log.addedAs(throwId, point);
          return;
        }
        // Another client (or a tool) changed a dart of this test
        final dart = log.byId(throwId);
        if (dart == null) return;
        setState(() {
          if (action == 'rejected') {
            dart.outcome == DartOutcome.missed ? log.remove(dart) : log.reject(dart);
          } else if (action == 'corrected' && point != null) {
            log.correct(dart, point);
          }
        });
      case EngineTakeout():
        setState(() {
          log.takeout(event);
          _selected = null;
        });
      default:
        break;
    }
  }

  /// A tap on the board: where the selected or the open dart really is, or a dart the engine missed
  void _onBoard(DartThrow input) {
    final engine = _engine!;
    final dart = _selected ?? log.current.darts.where((d) => d.open).firstOrNull;
    setState(() {
      if (dart == null) {
        log.missed(input.point);
        engine.addThrow(input.point);
      } else {
        log.correct(dart, input.point);
        if (dart.throwId case final id?) engine.correctThrow(id, input.point);
        _selected = null;
      }
    });
  }

  void _confirm(LoggedDart dart) {
    final guess = dart.detection?.point;
    if (guess == null) return;
    setState(() => log.confirm(dart));
    _engine!.correctThrow(dart.throwId!, guess);
  }

  void _reject(LoggedDart dart) {
    setState(() {
      log.reject(dart);
      if (identical(_selected, dart)) _selected = null;
    });
    if (dart.throwId case final id?) _engine!.rejectThrow(id, 'no dart landed (detection test)');
  }

  /// A missed dart added by mistake
  void _remove(LoggedDart dart) {
    setState(() => log.remove(dart));
    if (dart.throwId case final id?) _engine!.rejectThrow(id, 'added by mistake in the detection test');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = EngineScope.of(context);
    final theme = Theme.of(context);
    if (!engine.isConnected) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.detectionTest)),
        body: Center(child: Text(l10n.detectionTestNeedsEngine)),
      );
    }
    final round = log.current;
    final shown = [
      for (final d in round.darts)
        if (d.outcome != DartOutcome.falseAlarm && (d.truth ?? d.detection?.point) != null)
          DartThrow(d.truth ?? d.detection!.point!, ThrowInput.engine, geometry: log.geometry),
    ];

    final panel = ListView(
      children: [
        Text(l10n.detectionRound(log.rounds.length), style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          _selected == null ? l10n.detectionTestHint : l10n.detectionTestCorrecting,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final (i, d) in round.darts.indexed) _dartTile(l10n, theme, i, d),
        const SizedBox(height: 16),
        _Stats(log),
        const SizedBox(height: 16),
        _ParamsCard(engine),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.detectionTest)),
      body: GameLayout(
        input: ThrowInputPanel(geometry: log.geometry, shownThrows: shown, onThrow: _onBoard),
        panel: panel,
        panelWidth: 400,
      ),
    );
  }

  Widget _dartTile(AppLocalizations l10n, ThemeData theme, int index, LoggedDart d) {
    final detection = d.detection;
    final detected = detection?.point == null ? null : log.scoreOf(detection!.point!).label;
    final real = d.truth == null ? null : log.scoreOf(d.truth!).label;
    final (icon, color, outcome) = switch (d.outcome) {
      DartOutcome.right => (Icons.check_circle, Colors.green, l10n.outcomeRight),
      DartOutcome.wrong => (Icons.cancel, theme.colorScheme.error, l10n.outcomeWrong),
      DartOutcome.abstained => (Icons.help, theme.colorScheme.tertiary, l10n.outcomeAbstained),
      DartOutcome.missed => (Icons.visibility_off, theme.colorScheme.error, l10n.outcomeMissed),
      DartOutcome.falseAlarm => (Icons.block, theme.colorScheme.outline, l10n.outcomeFalseAlarm),
    };
    final title = switch (d.outcome) {
      DartOutcome.wrong || DartOutcome.abstained when real != null => '${detected ?? '–'} → $real',
      DartOutcome.missed => real ?? '–',
      _ => detected ?? '–',
    };
    final details = [
      outcome,
      if (detection != null) '${(100 * detection.confidence).round()} %',
      if (detection?.detectionLatencyMs case final ms?) '${ms.round()} ms',
      if (detection != null && detection.reason.isNotEmpty) detection.reason,
      for (final c in detection?.cameras ?? const <ThrowCamera>[])
        if (!c.used) '${c.camera}: ${c.reason.isEmpty ? '–' : c.reason}',
    ];
    final correctable = d.outcome != DartOutcome.falseAlarm && d.outcome != DartOutcome.missed;
    return Card(
      color: identical(_selected, d) ? theme.colorScheme.secondaryContainer : null,
      child: ListTile(
        key: ValueKey('logged-dart-$index'),
        leading: Icon(icon, color: color),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(details.join(' · ')),
        onTap: correctable ? () => setState(() => _selected = identical(_selected, d) ? null : d) : null,
        trailing: Wrap(
          spacing: 4,
          children: [
            if (d.open && detection?.point != null)
              TextButton(key: ValueKey('confirm-dart-$index'), onPressed: () => _confirm(d), child: Text(l10n.confirm)),
            if (detection != null && d.outcome != DartOutcome.falseAlarm)
              TextButton(key: ValueKey('reject-dart-$index'), onPressed: () => _reject(d), child: Text(l10n.noDart)),
            if (d.outcome == DartOutcome.missed)
              TextButton(key: ValueKey('remove-dart-$index'), onPressed: () => _remove(d), child: Text(l10n.delete)),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats(this.log);

  final DetectionLog log;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String ms(List<double> values) {
      final m = median(values);
      if (m == null) return '–';
      final max = values.reduce((a, b) => a > b ? a : b);
      return l10n.medianMax('${m.round()} ms', '${max.round()} ms');
    }

    final placedRight = log.placedRight;
    final errorMm = median(log.errorsMm);
    final rows = [
      (l10n.statDarts, '${log.realDarts}'),
      (
        l10n.statPlacedRight,
        placedRight == null
            ? '–'
            : '${(100 * placedRight).round()} % (${log.count(DartOutcome.right)}/${log.count(DartOutcome.right) + log.count(DartOutcome.wrong)})',
      ),
      (l10n.statAbstained, '${log.count(DartOutcome.abstained)}'),
      (l10n.statMissed, '${log.count(DartOutcome.missed)}'),
      (l10n.statFalseAlarms, '${log.count(DartOutcome.falseAlarm)}'),
      (l10n.statDetectionLatency, ms(log.detectionLatenciesMs)),
      (l10n.statProcessing, ms(log.processingLatenciesMs)),
      (l10n.statTakeoutLatency, ms(log.takeoutLatenciesMs)),
      (l10n.statTakeoutMismatches, '${log.takeoutMismatches}'),
      (l10n.statWrongBy, errorMm == null ? '–' : '${errorMm.toStringAsFixed(1)} mm'),
    ];
    return Card(
      key: const ValueKey('detection-stats'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
                    Text(value, key: ValueKey('stat-$label'), style: theme.textTheme.titleSmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sliders for the values of live detection, as the engine offers them
class _ParamsCard extends StatefulWidget {
  const _ParamsCard(this.engine);

  final EngineConnection engine;

  @override
  State<_ParamsCard> createState() => _ParamsCardState();
}

class _ParamsCardState extends State<_ParamsCard> {
  /// Values being dragged, before they are sent
  final Map<String, double> _dragging = {};

  Future<void> _set(String name, double value) async {
    final l10n = AppLocalizations.of(context);
    final error = await widget.engine.setDetectionParams({name: value});
    if (!mounted) return;
    setState(() => _dragging.remove(name));
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.detectionParamFailed(name, error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final params = widget.engine.detectionParams;
    return Card(
      key: const ValueKey('detection-params'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.detectionParams, style: theme.textTheme.titleMedium),
            if (params == null || params.ranges.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.detectionParamsUnavailable, style: theme.textTheme.bodySmall),
              )
            else
              for (final MapEntry(key: name, value: range) in params.ranges.entries) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(name)),
                    Text(
                      '${_format(_dragging[name] ?? params.params[name], range)} ${range.unit}'.trim(),
                      key: ValueKey('param-value-$name'),
                    ),
                  ],
                ),
                Slider(
                  key: ValueKey('param-$name'),
                  min: range.min,
                  max: range.max,
                  divisions: range.step == null || range.step! <= 0
                      ? null
                      : ((range.max - range.min) / range.step!).round().clamp(1, 1000),
                  value: (_dragging[name] ?? params.params[name] ?? range.min).clamp(range.min, range.max),
                  onChanged: (v) => setState(() => _dragging[name] = v),
                  onChangeEnd: (v) => _set(name, v),
                ),
              ],
          ],
        ),
      ),
    );
  }

  static String _format(double? value, ParamRange range) {
    if (value == null) return '–';
    final step = range.step;
    return step != null && step >= 1 && step == step.roundToDouble() ? '${value.round()}' : value.toStringAsFixed(2);
  }
}
