import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import '../stats/dart_links.dart';
import '../stats/statistics.dart';

/// The player's darts (#120): measured sets with their dimensions and reference images, each linked to the players
/// who throw it. Optional: without a set the engine detects any dart.
class MyDartsScreen extends StatelessWidget {
  const MyDartsScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final name = await _askName(context, title: l10n.addDartSet);
    if (name == null || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DartSetCaptureScreen(name: name)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = EngineScope.of(context);
    final sets = engine.dartSets;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myDarts)),
      floatingActionButton: sets == null
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('add-dart-set'),
              onPressed: () => _add(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.addDartSet),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(l10n.myDartsIntro),
          const SizedBox(height: 16),
          if (sets == null)
            Card(
              child: ListTile(
                key: const ValueKey('dart-sets-unavailable'),
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.dartSetsUnavailable),
              ),
            )
          else if (sets.sets.isEmpty)
            Card(
              child: ListTile(leading: const Icon(Icons.inbox_outlined), title: Text(l10n.noDartSets)),
            )
          else
            for (final set in sets.sets) _DartSetCard(set: set, active: sets.active == set.id),
        ],
      ),
    );
  }
}

Future<String?> _askName(BuildContext context, {required String title, String initial = ''}) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      void done() {
        final name = controller.text.trim();
        if (name.isNotEmpty) Navigator.of(dialogContext).pop(name);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          key: const ValueKey('dart-set-name'),
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.dartSetName, hintText: l10n.dartSetNameHint),
          onSubmitted: (_) => done(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.cancel)),
          FilledButton(key: const ValueKey('dart-set-name-ok'), onPressed: done, child: Text(l10n.dartSetStart)),
        ],
      );
    },
  );
}

/// One set: name, dimensions, reference images per camera, and the players who throw it
class _DartSetCard extends StatelessWidget {
  const _DartSetCard({required this.set, required this.active});

  final DartSet set;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final engine = EngineScope.of(context);
    final links = DartLinksScope.of(context);
    final players = StatisticsScope.maybeOf(context)?.profiles ?? const <String>[];
    String mm(String key) => set.dims[key] == null ? '–' : '${set.dims[key]!.toStringAsFixed(1)} mm';
    return Card(
      key: ValueKey('dart-set-${set.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(set.name, style: theme.textTheme.titleMedium)),
                if (active) Chip(label: Text(l10n.dartSetInUse), visualDensity: VisualDensity.compact),
                PopupMenuButton<String>(
                  key: ValueKey('dart-set-menu-${set.id}'),
                  onSelected: (action) async {
                    if (action == 'rename') {
                      final name = await _askName(context, title: l10n.renameDartSet, initial: set.name);
                      if (name != null) await engine.renameDartSet(set.id, name);
                    } else if (action == 'delete') {
                      final error = await engine.deleteDartSet(set.id);
                      if (error == null) await links.forgetSet(set.id);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(l10n.renameDartSet)),
                    PopupMenuItem(
                      value: 'delete',
                      key: ValueKey('delete-dart-set-${set.id}'),
                      child: Text(l10n.delete),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              [
                '${l10n.dartTotal} ${mm('total_mm')}',
                '${l10n.dartBarrel} ${mm('barrel_mm')} × ${mm('barrel_diameter_mm')}',
                if (set.dims['flight_mm'] != null) '${l10n.dartFlight} ${mm('flight_mm')}',
                if (set.dims['point_mm'] != null) '${l10n.dartPoint} ${mm('point_mm')}',
              ].join('  ·  '),
              style: theme.textTheme.bodySmall,
            ),
            if (set.cameras.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [for (final camera in set.cameras) _ReferenceImage(set: set.id, camera: camera)],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.dartSetThrownBy, style: theme.textTheme.labelLarge),
                for (final player in players)
                  FilterChip(
                    key: ValueKey('link-${set.id}-$player'),
                    label: Text(player),
                    selected: links.setOf(player) == set.id,
                    onSelected: (on) => links.link(player, on ? set.id : null),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceImage extends StatefulWidget {
  const _ReferenceImage({required this.set, required this.camera});

  final String set;
  final String camera;

  @override
  State<_ReferenceImage> createState() => _ReferenceImageState();
}

class _ReferenceImageState extends State<_ReferenceImage> {
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = EngineScope.of(context);
    if (!_asked && !engine.dartSetImages.containsKey((widget.set, widget.camera))) {
      _asked = true;
      engine.requestDartSetImage(widget.set, widget.camera);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = EngineScope.of(context).dartSetImages[(widget.set, widget.camera)];
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: image == null
                ? const Center(child: Icon(Icons.image_outlined))
                : Image.memory(
                    image.jpeg,
                    key: ValueKey('reference-${widget.set}-${widget.camera}'),
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Measuring a new set: one dart of it is put into the board at several places, each time with the hand away, as in
/// the setup diagnosis. The engine measures it from every camera.
class DartSetCaptureScreen extends StatefulWidget {
  const DartSetCaptureScreen({super.key, required this.name});

  final String name;

  @override
  State<DartSetCaptureScreen> createState() => _DartSetCaptureScreenState();
}

class _DartSetCaptureScreenState extends State<DartSetCaptureScreen> {
  String? _error;
  bool _started = false;
  EngineConnection? _engine;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _engine = EngineScope.of(context);
    if (_started) return;
    _started = true;
    _engine!.dartSetCapture = null;
    _engine!.startDartSet(widget.name).then((error) {
      if (mounted && error != null) setState(() => _error = error);
    });
  }

  @override
  void dispose() {
    final state = _engine?.dartSetCapture?.state;
    final saveFailed = state == 'failed' && _engine?.dartSetCapture?.reason == 'save_failed';
    if (state != null && state != 'done' && state != 'cancelled' && !saveFailed) _engine?.cancelDartSet();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final capture = EngineScope.of(context).dartSetCapture;
    // A failed place is not the end: the player pulls the dart and the next place counts. Only saving can fail for good.
    final failed = capture?.state == 'failed';
    final error = _error ?? (failed && capture?.reason == 'save_failed' ? 'save_failed' : null);
    final (icon, text) = switch (capture?.state) {
      _ when error != null => (Icons.error_outline, _errorText(l10n, error)),
      'failed' => (Icons.warning_amber, l10n.dartSetPlacementFailed(_placementReason(l10n, capture?.reason))),
      'measuring' => (Icons.hourglass_top, l10n.dartSetMeasuring),
      'placed' => (Icons.swap_horiz, l10n.dartSetPlaced),
      'done' => (Icons.check_circle, l10n.dartSetDone),
      _ => (Icons.touch_app, l10n.dartSetPutIn),
    };
    final done = capture?.state == 'done';
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(icon, size: 64, color: error != null ? theme.colorScheme.error : theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  text,
                  key: const ValueKey('dart-set-step'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                if (capture != null && error == null)
                  LinearProgressIndicator(value: capture.needed == 0 ? null : capture.placed / capture.needed),
                if (capture != null && capture.cameraStates.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        for (final MapEntry(key: camera, value: state) in capture.cameraStates.entries)
                          Chip(
                            key: ValueKey('capture-camera-$camera'),
                            avatar: Icon(
                              state == 'seen' ? Icons.check_circle : Icons.error_outline,
                              color: state == 'seen' ? Colors.green : theme.colorScheme.error,
                              size: 18,
                            ),
                            label: Text('${cameraLabelOf(context, camera)}: ${_cameraState(l10n, state)}'),
                          ),
                      ],
                    ),
                  ),
                if (capture != null && error == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.dartSetProgress(capture.placed, capture.needed),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('dart-set-close'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(done || error != null ? l10n.dartSetClose : l10n.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _cameraState(AppLocalizations l10n, String state) => switch (state) {
    'seen' => l10n.dartSeen,
    'cut' => l10n.dartCut,
    _ => l10n.dartNotSeen,
  };

  String _placementReason(AppLocalizations l10n, String? reason) => switch (reason) {
    'cameras_disagree' => l10n.dartSetCamerasDisagree,
    'seen_by_one_camera' => l10n.dartSetSeenByOne,
    'placements_disagree' => l10n.dartSetPlacementsDisagree,
    _ => l10n.dartSetNotMeasured,
  };

  String _errorText(AppLocalizations l10n, String code) => switch (code) {
    'save_failed' => l10n.dartSetSaveFailed,
    'not_calibrated' => l10n.dartSetNotCalibrated,
    'board_not_empty' => l10n.dartSetBoardNotEmpty,
    'busy' => l10n.dartSetBusy,
    _ => l10n.dartSetFailed(code),
  };
}

/// Tells the engine which darts the player at the board throws; called by game screens whenever that player may
/// have changed.
void useDartsOf(BuildContext context, String player) => context
    .getInheritedWidgetOfExactType<EngineScope>()
    ?.notifier
    ?.useDarts(DartLinksScope.read(context).setOf(player));

/// "Kamera 2" for the second camera of the engine; the id where it is not one of them
String cameraLabelOf(BuildContext context, String camera) {
  final cameras = EngineScope.of(context).hello?.cameras ?? const <String>[];
  final index = cameras.indexOf(camera);
  return index < 0 ? camera : AppLocalizations.of(context).cameraNumber(index + 1);
}
