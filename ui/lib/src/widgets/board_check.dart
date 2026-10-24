import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';

/// Before a game starts: true when the board is empty, unknown or no engine is connected; otherwise asks the player
/// to pull out the darts and is true once the board is empty or the player starts anyway.
Future<bool> confirmBoardEmpty(BuildContext context) async {
  final engine = EngineScope.of(context);
  if (!engine.isConnected || !(engine.boardState?.occupied ?? false)) return true;
  final start = await showDialog<bool>(context: context, builder: (_) => const BoardOccupiedDialog());
  return start ?? false;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
      Navigator.of(context).pop(true);
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
                Text(camera.reason.isEmpty ? camera.camera : '${camera.camera}: ${camera.reason}'),
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
        if (widget.allowStart)
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.startAnyway)),
      ],
    );
  }
}

/// The live image of a camera with a ring around the object it sees in the board.
class MarkedPreview extends StatefulWidget {
  const MarkedPreview({super.key, required this.board});

  final CameraBoardState board;

  @override
  State<MarkedPreview> createState() => _MarkedPreviewState();
}

class _MarkedPreviewState extends State<MarkedPreview> {
  PreviewHandle? _handle;
  StreamSubscription<PreviewFrame>? _frames;
  PreviewFrame? _frame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handle != null) return;
    final engine = EngineScope.of(context);
    _handle = engine.watchPreview(widget.board.camera, maxFps: 5, maxWidth: 640);
    _frames = engine.previews.where((f) => f.camera == widget.board.camera).listen((f) => setState(() => _frame = f));
  }

  @override
  void dispose() {
    _frames?.cancel();
    _handle?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    final aspect = frame == null || frame.height == 0 ? 16 / 9 : frame.width / frame.height;
    return AspectRatio(
      aspectRatio: aspect,
      child: frame == null
          ? Center(child: Text(AppLocalizations.of(context).waitingForImage))
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(frame.jpeg, fit: BoxFit.fill, gaplessPlayback: true),
                CustomPaint(painter: _MarkPainter(widget.board, Theme.of(context).colorScheme.error)),
              ],
            ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.board, this.color);

  final CameraBoardState board;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final point = board.imagePointPx;
    final image = board.imageSizePx;
    if (point == null || image == null) return;
    // The preview is a scaled copy of the image the point refers to.
    final centre = Offset(point.dx / image.width * size.width, point.dy / image.height * size.height);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(centre, size.shortestSide * 0.08, paint);
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.board.imagePointPx != board.imagePointPx || old.board.imageSizePx != board.imageSizePx || old.color != color;
}

/// In the engine card: a warning while the board is occupied, and the action to store the empty board.
class BoardStateRow extends StatelessWidget {
  const BoardStateRow({super.key});

  Future<void> _store(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error = await EngineScope.of(context).storeEmptyReference();
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (error) {
          null => l10n.emptyReferenceStored,
          'board_not_empty' => l10n.boardNotEmpty,
          _ => l10n.storeReferenceFailed,
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final board = EngineScope.of(context).boardState;
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
        TextButton(onPressed: () => _store(context), child: Text(l10n.storeEmptyReference)),
      ],
    );
  }
}
