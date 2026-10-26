import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import '../stats/dart_links.dart';
import '../stats/statistics.dart';
import '../widgets/board_check.dart';
import '../widgets/precision_text.dart';

/// The player's darts (#120): measured sets with their dimensions and reference images, each linked to the players
/// who throw it. Optional: without a set the engine detects any dart.
class MyDartsScreen extends StatelessWidget {
  const MyDartsScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final engine = EngineScope.of(context);
    final how = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('add-set-measure'),
              leading: const Icon(Icons.adjust),
              title: Text(l10n.addSetMeasure),
              subtitle: Text(l10n.addSetMeasureHint),
              onTap: () => Navigator.of(sheetContext).pop('measure'),
            ),
            ListTile(
              key: const ValueKey('add-set-photo'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.addSetPhoto),
              subtitle: Text(l10n.addSetPhotoHint),
              onTap: () => Navigator.of(sheetContext).pop('photo'),
            ),
            ListTile(
              key: const ValueKey('add-set-enter'),
              leading: const Icon(Icons.edit_note),
              title: Text(l10n.addSetEnter),
              subtitle: Text(l10n.addSetEnterHint),
              onTap: () => Navigator.of(sheetContext).pop('enter'),
            ),
          ],
        ),
      ),
    );
    if (how == null || !context.mounted) return;
    final name = await _askName(context, title: l10n.addDartSet);
    if (name == null || !context.mounted) return;
    if (how == 'measure') {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DartSetCaptureScreen(name: name)));
      return;
    }
    if (how == 'photo') {
      final before = {for (final s in engine.dartSets?.sets ?? const <DartSet>[]) s.id};
      final error = await engine.createDartSet(name, const {});
      if (!context.mounted) return;
      if (error != null) return _showDimsError(context, error);
      final id = await _newSetId(engine, before);
      if (id != null && context.mounted) await measureByPhoto(context, id);
      return;
    }
    final dims = await showDialog<Map<String, double?>>(
      context: context,
      builder: (_) => DartDimsDialog(title: name),
    );
    if (dims == null || !context.mounted) return;
    final error = await engine.createDartSet(name, {for (final MapEntry(:key, :value) in dims.entries) key: ?value});
    if (error != null && context.mounted) _showDimsError(context, error);
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

Future<String?> _askName(BuildContext context, {required String title, String initial = ''}) => showDialog<String>(
  context: context,
  builder: (_) => _NameDialog(title: title, initial: initial),
);

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('dart-set-name'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.dartSetName, hintText: l10n.dartSetNameHint),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(key: const ValueKey('dart-set-name-ok'), onPressed: _done, child: Text(l10n.dartSetStart)),
      ],
    );
  }
}

/// Asks before a set and its reference images are deleted
Future<bool> _confirmDelete(BuildContext context, DartSet set) async {
  final l10n = AppLocalizations.of(context);
  final delete = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.deleteDartSetTitle(set.name)),
      content: Text(l10n.deleteDartSetText),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel)),
        FilledButton(
          key: const ValueKey('delete-dart-set-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return delete == true;
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
                    if (action == 'photo') {
                      await measureByPhoto(context, set.id);
                    } else if (action == 'dims') {
                      final dims = await showDialog<Map<String, double?>>(
                        context: context,
                        builder: (_) => DartDimsDialog(title: set.name, set: set),
                      );
                      if (dims == null || dims.isEmpty) return;
                      final error = await engine.updateDartSet(set.id, dims);
                      if (error != null && context.mounted) _showDimsError(context, error);
                    } else if (action == 'rename') {
                      final name = await _askName(context, title: l10n.renameDartSet, initial: set.name);
                      if (name == null) return;
                      final error = await engine.renameDartSet(set.id, name);
                      if (error != null && context.mounted) _showDimsError(context, error);
                    } else if (action == 'delete') {
                      if (!await _confirmDelete(context, set)) return;
                      final error = await engine.deleteDartSet(set.id);
                      if (error == null) {
                        await links.forgetSet(set.id);
                      } else if (context.mounted) {
                        _showDimsError(context, error);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'dims', key: ValueKey('edit-dims-${set.id}'), child: Text(l10n.enterDims)),
                    PopupMenuItem(value: 'photo', key: ValueKey('photo-${set.id}'), child: Text(l10n.addSetPhoto)),
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
                for (final dim in dartDims)
                  if (set.dims[dim.key] != null)
                    '${dim.label(l10n)} ${dim.format(l10n, set.dims[dim.key]!)}${_source(l10n, set, dim.key)}',
              ].join('  ·  '),
              key: ValueKey('dart-set-dims-${set.id}'),
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
                // Between places the engine waits for the empty board; a stale empty-board image never lets it.
                if ((capture?.state == 'placed' || capture?.state == 'failed') &&
                    (EngineScope.of(context).boardState?.occupied ?? false))
                  Card(
                    key: const ValueKey('dart-set-board-occupied'),
                    color: theme.colorScheme.tertiaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.crop_free),
                      title: Text(l10n.dartSetBoardStillOccupied),
                      trailing: TextButton(
                        onPressed: () => storeEmptyBoard(context),
                        child: Text(l10n.storeEmptyReference),
                      ),
                    ),
                  ),
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

/// The dimensions of a dart set, in the order the app shows them
class DartDim {
  const DartDim(this.key, this.label, {this.unit = 'mm'});

  final String key;
  final String Function(AppLocalizations) label;
  final String unit;

  String format(AppLocalizations l10n, double value) => '${decimal(l10n, value)} $unit';
}

final List<DartDim> dartDims = [
  DartDim('total_mm', (l) => l.dimTotal),
  DartDim('point_mm', (l) => l.dimPoint),
  DartDim('barrel_mm', (l) => l.dimBarrel),
  DartDim('barrel_diameter_mm', (l) => l.dimBarrelDiameter),
  DartDim('shaft_mm', (l) => l.dimShaft),
  DartDim('flight_mm', (l) => l.dimFlight),
  DartDim('weight_g', (l) => l.dimWeight, unit: 'g'),
];

/// " (eingegeben)" for an entered value, " (unsicher)" for a measured barrel, nothing otherwise
String _source(AppLocalizations l10n, DartSet set, String key) => switch (set.dimsSource[key]) {
  'entered' => ' (${l10n.dimEntered})',
  'photo' => ' (${l10n.dimPhoto})',
  // The engine measures the barrel from the dart's outline, less reliably than its length (#208).
  _ when key == 'barrel_mm' || key == 'barrel_diameter_mm' => ' (${l10n.dartMeasureUncertain})',
  _ => '',
};

void _showDimsError(BuildContext context, String error) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(error == 'bad_request' ? l10n.dimsImplausible : l10n.dartSetFailed(error))));
}

/// Typing in a set's dimensions, e.g. from the packaging. Returns the changes: a number to enter, null to remove an
/// entered value so the measured one counts again; empty fields that had no entered value stay out.
class DartDimsDialog extends StatefulWidget {
  const DartDimsDialog({super.key, required this.title, this.set});

  final String title;
  final DartSet? set;

  @override
  State<DartDimsDialog> createState() => _DartDimsDialogState();
}

class _DartDimsDialogState extends State<DartDimsDialog> {
  late final Map<String, TextEditingController> _fields = {
    for (final dim in dartDims)
      dim.key: TextEditingController(
        text: widget.set?.dimsSource[dim.key] == 'entered' ? _text(widget.set!.dims[dim.key]) : '',
      ),
  };

  static String _text(double? v) => v == null ? '' : (v == v.roundToDouble() ? '${v.round()}' : '$v');

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, double?> _changes() {
    final changes = <String, double?>{};
    for (final dim in dartDims) {
      final text = _fields[dim.key]!.text.trim().replaceAll(',', '.');
      final value = double.tryParse(text);
      final wasEntered = widget.set?.dimsSource[dim.key] == 'entered';
      if (value != null && (!wasEntered || value != widget.set!.dims[dim.key])) {
        changes[dim.key] = value;
      } else if (text.isEmpty && wasEntered) {
        changes[dim.key] = null;
      }
    }
    return changes;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final set = widget.set;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.dimsHint, style: Theme.of(context).textTheme.bodySmall),
              for (final dim in dartDims)
                TextField(
                  key: ValueKey('dim-${dim.key}'),
                  controller: _fields[dim.key],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: dim.label(l10n),
                    suffixText: dim.unit,
                    helperText: set?.measured[dim.key] == null
                        ? null
                        : l10n.dimMeasuredValue(dim.format(l10n, set!.measured[dim.key]!)),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          key: const ValueKey('dims-save'),
          onPressed: () => Navigator.of(context).pop(_changes()),
          child: Text(l10n.dimsSave),
        ),
      ],
    );
  }
}

/// The id of the set that appears in [EngineConnection.dartSets] next to `before`, once the engine sent it
Future<String?> _newSetId(EngineConnection engine, Set<String> before) async {
  String? find() => engine.dartSets?.sets.map((s) => s.id).where((id) => !before.contains(id)).firstOrNull;
  if (find() case final id?) return id;
  final found = Completer<String?>();
  void listener() {
    if (find() case final id? when !found.isCompleted) found.complete(id);
  }

  engine.addListener(listener);
  try {
    return await found.future.timeout(const Duration(seconds: 5), onTimeout: () => null);
  } finally {
    engine.removeListener(listener);
  }
}

/// Takes the photo of the dart on its sheet: the camera on phones, a picture file elsewhere. Downscaled to at most
/// 3000 px and JPEG quality 90, as the engine needs the whole sheet sharp but not the camera's full size.
@visibleForTesting
Future<Uint8List?> Function() takeDartPhoto = () async {
  final camera =
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  final file = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 3000,
    maxHeight: 3000,
    imageQuality: 90,
  );
  return file?.readAsBytes();
};

/// The photo measurement of a set (#120): how to lay the dart on the printed sheet, the photo, and the engine's answer
Future<void> measureByPhoto(BuildContext context, String id) async {
  final l10n = AppLocalizations.of(context);
  final engine = EngineScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.addSetPhoto),
      content: Text(l10n.dartPhotoHowTo),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel)),
        FilledButton(
          key: const ValueKey('dart-photo-take'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.dartPhotoTake),
        ),
      ],
    ),
  );
  if (go != true) return;
  final jpeg = await takeDartPhoto();
  if (jpeg == null) return;
  messenger.showSnackBar(SnackBar(content: Text(l10n.dartPhotoMeasuring)));
  final error = await engine.measureDartPhoto(id, jpeg);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const ValueKey('dart-photo-result'),
        content: Text(switch (error) {
          null => l10n.dartPhotoDone,
          'sheet_not_found' => l10n.dartPhotoNoSheet,
          'dart_not_found' => l10n.dartPhotoNoDart,
          _ => l10n.dartSetFailed(error),
        }),
      ),
    );
}
