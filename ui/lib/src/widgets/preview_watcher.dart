import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import '../theme.dart';

/// Keeps the newest preview frame of a camera and measures the preview rate while it is watched.
mixin PreviewWatcher<T extends StatefulWidget> on State<T> {
  EngineConnection? _engine;
  PreviewHandle? _handle;
  StreamSubscription<PreviewFrame>? _frames;
  PreviewFrame? frame;
  final List<DateTime> _arrivals = [];
  Timer? _tick;

  /// Whole seconds since the last frame while watched; the image then shows that it is old
  int secondsWithoutFrame = 0;

  String get watchedCamera;
  double get previewFps;
  int get previewWidth;

  /// Frames per second over the last two seconds
  double get previewRate {
    final now = DateTime.now();
    return _arrivals.where((t) => now.difference(t) <= const Duration(seconds: 2)).length / 2.0;
  }

  void startWatching() {
    // Frames come through the stream; the widget does not rebuild with every change of the connection.
    final engine = EngineScope.read(context);
    if (identical(engine, _engine) && _handle != null) return;
    stopWatching();
    _engine = engine;
    _handle = engine.watchPreview(watchedCamera, maxFps: previewFps, maxWidth: previewWidth);
    _frames = engine.previews
        .where((f) => f.camera == watchedCamera)
        .listen(
          (f) => setState(() {
            frame = f;
            _arrivals.add(DateTime.now());
            secondsWithoutFrame = 0;
          }),
        );
    // Rate and age change while no frame arrives, too.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      setState(() {
        _arrivals.removeWhere((t) => now.difference(t) > const Duration(seconds: 2));
        secondsWithoutFrame++;
      });
    });
  }

  /// Watches again from scratch, after the camera, rate or width changed
  void restartWatching() {
    stopWatching();
    frame = null;
    startWatching();
  }

  void stopWatching() {
    _tick?.cancel();
    _tick = null;
    secondsWithoutFrame = 0;
    _frames?.cancel();
    _handle?.release();
    _frames = null;
    _handle = null;
    _arrivals.clear();
  }

  @override
  void dispose() {
    stopWatching();
    super.dispose();
  }
}

/// A camera image with a note over it once no new frame came for [seconds], so a frozen image does not look live
class StaleFrame extends StatelessWidget {
  const StaleFrame({super.key, required this.seconds, required this.child});

  /// Shown from two seconds on, at a preview rate of 10 fps and more
  static const int staleAfterSeconds = 2;

  final int seconds;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (seconds < staleAfterSeconds) return child;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0.4, child: child),
        Chip(
          key: const ValueKey('camera-stale'),
          avatar: Icon(Icons.hourglass_empty, color: StatusColors.of(context).warning),
          label: Text(AppLocalizations.of(context).cameraNoFrameFor(seconds)),
        ),
      ],
    );
  }
}
