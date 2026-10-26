import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/camera_order.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import 'overlay_preview.dart';

/// Before a game starts: true when the board is empty, unknown or no engine is connected; otherwise asks the player
/// to pull out the darts and is true once the board is empty or the player starts anyway.
Future<bool> confirmBoardEmpty(BuildContext context) async {
  final engine = EngineScope.read(context);
  if (!engine.isConnected || !(engine.boardState?.occupied ?? false)) return true;
  final start = await showDialog<bool>(context: context, builder: (_) => const BoardOccupiedDialog());
  return start ?? false;
}

/// Stores the empty board and tells the player how it went
Future<void> storeEmptyBoard(BuildContext context, {bool force = false}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final error = await EngineScope.read(context).storeEmptyReference(force: force);
  messenger.showSnackBar(
    SnackBar(
      content: Text(switch (error) {
        null => l10n.emptyReferenceStored,
        'board_not_empty' => l10n.boardNotEmpty,
        'not_still' => l10n.boardNotStill,
        _ => l10n.storeReferenceFailed,
      }),
    ),
  );
}

Future<void> _confirmEmpty(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.boardIsEmptyTitle),
      content: Text(l10n.boardIsEmptyText),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.storeEmptyReference)),
      ],
    ),
  );
  if (confirmed == true && context.mounted) await storeEmptyBoard(context, force: true);
}

/// Shows which cameras see an object in the board, with the object marked in their image. Closes by itself with
/// true when the board becomes empty.
class BoardOccupiedDialog extends StatefulWidget {
  const BoardOccupiedDialog({super.key, this.allowStart = true});

  /// false where nothing is started, e.g. from the engine card
  final bool allowStart;

  @override
  State<BoardOccupiedDialog> createState() => _BoardOccupiedDialogState();
}

class _BoardOccupiedDialogState extends State<BoardOccupiedDialog> {
  EngineConnection? _engine;
  ModalRoute<Object?>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    final engine = EngineScope.of(context);
    if (!identical(engine, _engine)) {
      _engine?.removeListener(_onChange);
      _engine = engine..addListener(_onChange);
    }
  }

  @override
  void dispose() {
    _engine?.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final engine = _engine!;
    if (!engine.isConnected || !(engine.boardState?.occupied ?? false)) {
      _engine?.removeListener(_onChange);
      // A question asked from this dialog, such as storing the empty board, has no answer any more.
      final navigator = Navigator.of(context);
      navigator.popUntil((route) => route == _route);
      navigator.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = EngineScope.of(context);
    final cameras = engine.boardState?.cameras.where((c) => c.occupied).toList() ?? const <CameraBoardState>[];
    return AlertDialog(
      icon: const Icon(Icons.warning_amber, size: 36),
      title: Text(l10n.boardOccupiedTitle),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.boardOccupiedText),
              for (final camera in cameras) ...[
                const SizedBox(height: 12),
                Text(
                  // The engine's reason is an English sentence; in other languages the marked image says where.
                  camera.reason.isEmpty || !l10n.localeName.startsWith('en')
                      ? cameraLabel(context, camera.camera)
                      : '${cameraLabel(context, camera.camera)}: ${camera.reason}',
                ),
                const SizedBox(height: 4),
                MarkedPreview(key: ValueKey('board-preview-${camera.camera}'), board: camera),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
        TextButton(onPressed: engine.checkBoard, child: Text(l10n.checkBoardAgain)),
        // The check can be wrong (#121); the player looks at the real board and may replace the empty image.
        TextButton(onPressed: () => _confirmEmpty(context), child: Text(l10n.boardIsEmpty)),
        if (widget.allowStart)
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.startAnyway)),
      ],
    );
  }
}

/// The live image of a camera with a ring around the object it sees in the board.
class MarkedPreview extends StatelessWidget {
  const MarkedPreview({super.key, required this.board});

  final CameraBoardState board;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return OverlayPreview(
      camera: board.camera,
      imageSizePx: board.imageSizePx,
      maxFps: 5,
      repaintKey: (board.imagePointPx, color),
      paint: (canvas, size, scale) {
        final point = board.imagePointPx;
        if (point == null) return;
        final ring = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(point * scale, size.shortestSide * 0.08, ring);
      },
    );
  }
}

/// In the engine card: a warning while the board is occupied, and the action to store the empty board.
class BoardStateRow extends StatelessWidget {
  const BoardStateRow({super.key});

  @override
  Widget build(BuildContext context) {
    return EngineSelect(select: (engine) => engine.boardState, builder: _build);
  }

  Widget _build(BuildContext context, EngineBoardState? board) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (board == null) return const SizedBox.shrink();
    if (board.occupied) {
      return Row(
        key: const ValueKey('board-occupied'),
        children: [
          Icon(Icons.warning_amber, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.boardOccupiedBanner)),
          TextButton(
            onPressed: () =>
                showDialog<bool>(context: context, builder: (_) => const BoardOccupiedDialog(allowStart: false)),
            child: Text(l10n.show),
          ),
        ],
      );
    }
    if (board.referenceStored) return const SizedBox.shrink();
    return Row(
      key: const ValueKey('board-reference-missing'),
      children: [
        Icon(Icons.info_outline, color: theme.colorScheme.secondary),
        const SizedBox(width: 8),
        Expanded(child: Text(l10n.emptyReferenceMissing)),
        TextButton(onPressed: () => storeEmptyBoard(context), child: Text(l10n.storeEmptyReference)),
      ],
    );
  }
}
