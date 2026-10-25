import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import '../input/throw_input_panel.dart';
import '../stats/detection_log.dart';
import '../stats/param_profiles.dart';
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

/// The values of live detection as the engine offers them: grouped by pipeline stage, with what each one does,
/// marked when changed from the default, and named profiles to return to a setting that worked
class _ParamsCard extends StatefulWidget {
  const _ParamsCard(this.engine);

  final EngineConnection engine;

  @override
  State<_ParamsCard> createState() => _ParamsCardState();
}

class _ParamsCardState extends State<_ParamsCard> {
  /// Values being dragged, before they are sent
  final Map<String, double> _dragging = {};
  Map<String, Map<String, double>> _profiles = {};

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await ParamProfiles.load();
    if (mounted) setState(() => _profiles = profiles);
  }

  Future<void> _set(Map<String, double> values) async {
    final l10n = AppLocalizations.of(context);
    final error = await widget.engine.setDetectionParams(values);
    if (!mounted) return;
    setState(() => values.keys.forEach(_dragging.remove));
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.detectionParamFailed(values.keys.join(', '), error))));
    }
  }

  Future<void> _saveProfile(DetectionParams params) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.saveParamProfile),
        content: TextField(
          key: const ValueKey('param-profile-name'),
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.paramProfileName),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.cancel)),
          FilledButton(
            key: const ValueKey('param-profile-save'),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.saveParamProfile),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await ParamProfiles.save(name.trim(), {for (final n in params.ranges.keys) n: ?params.params[n]});
    await _loadProfiles();
  }

  Future<void> _deleteProfile(String name) async {
    await ParamProfiles.delete(name);
    await _loadProfiles();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final params = widget.engine.detectionParams;
    final groups = <String, List<String>>{};
    for (final name in params?.ranges.keys ?? const <String>[]) {
      groups.putIfAbsent(params!.info[name]?.group ?? '', () => []).add(name);
    }
    final changed = [
      for (final MapEntry(key: name, value: info) in params?.info.entries ?? const <MapEntry<String, ParamInfo>>[])
        if (info.defaultValue != null && params!.params[name] != null && params.params[name] != info.defaultValue) name,
    ];
    return Card(
      key: const ValueKey('detection-params'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.detectionParams, style: theme.textTheme.titleMedium)),
                if (changed.isNotEmpty)
                  TextButton(
                    key: const ValueKey('params-reset-all'),
                    onPressed: () => _set({for (final n in changed) n: params!.info[n]!.defaultValue!}),
                    child: Text(l10n.resetAllParams),
                  ),
              ],
            ),
            if (params == null || params.ranges.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.detectionParamsUnavailable, style: theme.textTheme.bodySmall),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final name in _profiles.keys)
                    InputChip(
                      key: ValueKey('param-profile-$name'),
                      label: Text(name),
                      onPressed: () =>
                          _set(Map.of(_profiles[name]!)..removeWhere((k, _) => !params.ranges.containsKey(k))),
                      onDeleted: () => _deleteProfile(name),
                    ),
                  ActionChip(
                    key: const ValueKey('param-profile-new'),
                    avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: Text(l10n.saveParamProfile),
                    onPressed: () => _saveProfile(params),
                  ),
                ],
              ),
              for (final MapEntry(key: group, value: names) in groups.entries) ...[
                const SizedBox(height: 12),
                if (group.isNotEmpty)
                  Text(group, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                for (final name in names) _param(l10n, theme, params, name),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _param(AppLocalizations l10n, ThemeData theme, DetectionParams params, String name) {
    final range = params.ranges[name]!;
    final info = params.info[name];
    final value = params.params[name];
    final defaultValue = info?.defaultValue;
    final changed = defaultValue != null && value != null && value != defaultValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            if (changed) Icon(Icons.edit, size: 14, color: theme.colorScheme.tertiary),
            if (changed) const SizedBox(width: 4),
            Expanded(
              child: Text(name, style: changed ? TextStyle(color: theme.colorScheme.tertiary) : null),
            ),
            Text(
              '${_format(_dragging[name] ?? value, range)} ${range.unit}'.trim(),
              key: ValueKey('param-value-$name'),
            ),
            if (changed)
              IconButton(
                key: ValueKey('param-reset-$name'),
                tooltip: l10n.resetParam(_format(defaultValue, range)),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.restart_alt, size: 18),
                onPressed: () => _set({name: defaultValue}),
              ),
          ],
        ),
        if (info != null && info.description.isNotEmpty) Text(info.description, style: theme.textTheme.bodySmall),
        Slider(
          key: ValueKey('param-$name'),
          min: range.min,
          max: range.max,
          divisions: range.step == null || range.step! <= 0
              ? null
              : ((range.max - range.min) / range.step!).round().clamp(1, 1000),
          value: (_dragging[name] ?? value ?? range.min).clamp(range.min, range.max),
          onChanged: (v) => setState(() => _dragging[name] = v),
          onChangeEnd: (v) => _set({name: v}),
        ),
      ],
    );
  }

  static String _format(double? value, ParamRange range) {
    if (value == null) return '–';
    final step = range.step;
    return step != null && step >= 1 && step == step.roundToDouble() ? '${value.round()}' : value.toStringAsFixed(2);
  }
}
