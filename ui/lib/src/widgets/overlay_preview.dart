import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';

/// Draws on top of a camera image. [scale] maps the camera's full-image pixels (the engine's coordinates) to the
/// widget, so `Offset(x, y) * scale` is where the image pixel (x, y) appears.
typedef OverlayPainter = void Function(Canvas canvas, Size size, double scale);

/// The live image of a camera with drawings on top, and taps reported in the camera's full-image pixels: what the
/// calibration pages use to show what the engine found and to let the player point at the board.
class OverlayPreview extends StatefulWidget {
  const OverlayPreview({
    super.key,
    required this.camera,
    this.imageSizePx,
    this.paint,
    this.repaintKey,
    this.onTapImagePx,
    this.maxFps = 10,
    this.maxWidth = 640,
  });

  final String camera;

  /// Size of the image the engine's coordinates refer to (e.g. 1280×720); the preview's own size when null, which is
  /// only right while the engine sends it unscaled
  final Size? imageSizePx;
  final OverlayPainter? paint;

  /// Changes whenever what [paint] draws changes, so the overlay is repainted without a new frame
  final Object? repaintKey;
  final ValueChanged<Offset>? onTapImagePx;
  final double maxFps;
  final int maxWidth;

  @override
  State<OverlayPreview> createState() => _OverlayPreviewState();
}

class _OverlayPreviewState extends State<OverlayPreview> {
  EngineConnection? _engine;
  PreviewHandle? _handle;
  StreamSubscription<PreviewFrame>? _frames;
  PreviewFrame? _frame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watch();
  }

  @override
  void didUpdateWidget(OverlayPreview old) {
    super.didUpdateWidget(old);
    if (old.camera != widget.camera || old.maxFps != widget.maxFps || old.maxWidth != widget.maxWidth) {
      _release();
      _frame = null;
      _watch();
    }
  }

  void _watch() {
    final engine = EngineScope.of(context);
    if (identical(engine, _engine) && _handle != null) return;
    _release();
    _engine = engine;
    _handle = engine.watchPreview(widget.camera, maxFps: widget.maxFps, maxWidth: widget.maxWidth);
    _frames = engine.previews.where((f) => f.camera == widget.camera).listen((f) => setState(() => _frame = f));
  }

  void _release() {
    _frames?.cancel();
    _handle?.release();
    _frames = null;
    _handle = null;
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    final imageSize =
        widget.imageSizePx ?? (frame == null ? null : Size(frame.width.toDouble(), frame.height.toDouble()));
    final aspect = imageSize == null || imageSize.height == 0 ? 16 / 9 : imageSize.width / imageSize.height;
    return AspectRatio(
      aspectRatio: aspect,
      child: frame == null || imageSize == null
          ? ColoredBox(
              color: Colors.black,
              child: Center(child: Text(AppLocalizations.of(context).waitingForImage)),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final scale = constraints.maxWidth / imageSize.width;
                final painter = widget.paint;
                return GestureDetector(
                  key: ValueKey('overlay-preview-${widget.camera}'),
                  onTapUp: widget.onTapImagePx == null
                      ? null
                      : (details) => widget.onTapImagePx!(details.localPosition / scale),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(frame.jpeg, fit: BoxFit.fill, gaplessPlayback: true),
                      if (painter != null) CustomPaint(painter: _Overlay(painter, scale, widget.repaintKey)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _Overlay extends CustomPainter {
  _Overlay(this.draw, this.scale, this.key);

  final OverlayPainter draw;
  final double scale;
  final Object? key;

  @override
  void paint(Canvas canvas, Size size) => draw(canvas, size, scale);

  @override
  bool shouldRepaint(_Overlay old) => old.scale != scale || old.key != key;
}
