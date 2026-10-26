import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/camera_order.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import '../engine/engine_errors.dart';
import '../widgets/live_jpeg.dart';

/// All cameras of the engine with a live image, to put them in the player's order and name them: once when new
/// cameras appear, and whenever two should swap places.
class CameraAssignScreen extends StatefulWidget {
  const CameraAssignScreen({super.key});

  @override
  State<CameraAssignScreen> createState() => _CameraAssignScreenState();
}

class _CameraAssignScreenState extends State<CameraAssignScreen> {
  List<String>? _order;
  final Map<String, TextEditingController> _names = {};
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final order = CameraOrderScope.of(context);
    final cameras = orderedCameras(context);
    // Cameras can come and go while the page is open: keep the player's order for those that stay.
    _order = [
      for (final id in _order ?? const <String>[])
        if (cameras.contains(id)) id,
      for (final id in cameras)
        if (!(_order?.contains(id) ?? false)) id,
    ];
    for (final id in _order!) {
      _names.putIfAbsent(id, () => TextEditingController(text: order.nameOf(id) ?? ''));
    }
  }

  /// Order or names differ from what is stored: leaving asks first
  bool _changed(BuildContext context) {
    final order = CameraOrderScope.of(context);
    return !listEquals(_order, orderedCameras(context)) ||
        _names.entries.any((e) => e.value.text != (order.nameOf(e.key) ?? ''));
  }

  Future<void> _confirmLeave() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.discardCameraOrderTitle),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.discard)),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    for (final c in _names.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _swap(int a, int b) => setState(() {
    final order = _order!;
    final id = order[a];
    order[a] = order[b];
    order[b] = id;
  });

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    final error = await CameraOrderScope.of(context)
        .assign(_order!, {for (final MapEntry(:key, :value) in _names.entries) key: value.text});
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(engineErrorText(l10n, error) ?? l10n.cameraAssignFailed(error))));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final order = _order!;
    return PopScope(
      // Typing a name does not rebuild the page, so whether something changed is decided on leaving.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _changed(context) ? _confirmLeave() : Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.assignCameras)),
        body: order.isEmpty
            ? Center(child: Text(EngineScope.of(context).isConnected ? l10n.noCameras : l10n.diagnosisNeedsEngine))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(l10n.assignCamerasHint, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  for (final (i, id) in order.indexed)
                    Card(
                      key: ValueKey('assign-$id'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow = constraints.maxWidth < 560;
                            final thumbnail = SizedBox(
                              width: narrow ? double.infinity : 240,
                              child: CameraThumbnail(camera: id),
                            );
                            final row = Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(child: Text('${i + 1}', key: ValueKey('assign-number-$id'))),
                                const SizedBox(width: 12),
                                if (!narrow) ...[thumbnail, const SizedBox(width: 12)],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TextField(
                                        key: ValueKey('assign-name-$id'),
                                        controller: _names[id],
                                        decoration: InputDecoration(
                                          labelText: l10n.cameraNameLabel,
                                          hintText: l10n.cameraNumber(i + 1),
                                          isDense: true,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(id, style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      key: ValueKey('assign-up-$id'),
                                      tooltip: l10n.moveCameraUp,
                                      onPressed: i == 0 ? null : () => _swap(i, i - 1),
                                      icon: const Icon(Icons.arrow_upward),
                                    ),
                                    IconButton(
                                      key: ValueKey('assign-down-$id'),
                                      tooltip: l10n.moveCameraDown,
                                      onPressed: i == order.length - 1 ? null : () => _swap(i, i + 1),
                                      icon: const Icon(Icons.arrow_downward),
                                    ),
                                  ],
                                ),
                              ],
                            );
                            return narrow ? Column(children: [thumbnail, const SizedBox(height: 8), row]) : row;
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      key: const ValueKey('assign-save'),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: Text(l10n.saveCameraOrder),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A small live image of a camera, for telling the cameras apart
class CameraThumbnail extends StatefulWidget {
  const CameraThumbnail({super.key, required this.camera});

  final String camera;

  @override
  State<CameraThumbnail> createState() => _CameraThumbnailState();
}

class _CameraThumbnailState extends State<CameraThumbnail> {
  EngineConnection? _engine;
  PreviewHandle? _handle;
  StreamSubscription<PreviewFrame>? _frames;
  PreviewFrame? _frame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = EngineScope.of(context);
    if (identical(engine, _engine)) return;
    _stop();
    _engine = engine;
    _handle = engine.watchPreview(widget.camera, maxFps: 5, maxWidth: 320);
    _frames = engine.previews.where((f) => f.camera == widget.camera).listen((f) => setState(() => _frame = f));
  }

  void _stop() {
    _frames?.cancel();
    _handle?.release();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: frame == null
              ? Center(child: Text(AppLocalizations.of(context).waitingForImage))
              : LiveJpeg(frame.jpeg, key: ValueKey('thumbnail-${widget.camera}')),
        ),
      ),
    );
  }
}
