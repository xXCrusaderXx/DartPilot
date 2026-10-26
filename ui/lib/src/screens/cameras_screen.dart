import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../../l10n/app_localizations.dart';
import '../engine/camera_order.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import 'camera_assign_screen.dart';
import '../widgets/live_jpeg.dart';

/// Live images of the engine's cameras with their status. Each camera is a panel that can be collapsed, which also
/// stops its preview; tapping an image opens it full screen.
class CamerasScreen extends StatefulWidget {
  const CamerasScreen({super.key});

  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  EngineConnection? _engine;
  final Set<String> _collapsed = {};

  /// While a camera is shown full screen, the panels underneath stop their previews.
  bool _fullscreen = false;

  Future<void> _openFullscreen(String camera) async {
    setState(() => _fullscreen = true);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CameraFullscreen(camera: camera)));
    if (mounted) setState(() => _fullscreen = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = EngineScope.of(context);
    if (identical(engine, _engine)) return;
    _engine?.unwatchStatus();
    _engine = engine..watchStatus();
  }

  @override
  void dispose() {
    _engine?.unwatchStatus();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cameras = orderedCameras(context);
    final allCollapsed = cameras.isNotEmpty && cameras.every(_collapsed.contains);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cameras),
        actions: [
          if (cameras.isNotEmpty)
            IconButton(
              key: const ValueKey('assign-cameras'),
              tooltip: l10n.assignCameras,
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CameraAssignScreen())),
              icon: const Icon(Icons.swap_vert),
            ),
          if (cameras.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => allCollapsed ? _collapsed.clear() : _collapsed.addAll(cameras)),
              icon: Icon(allCollapsed ? Icons.unfold_more : Icons.unfold_less),
              label: Text(allCollapsed ? l10n.expandAll : l10n.collapseAll),
            ),
        ],
      ),
      body: cameras.isEmpty
          ? Center(child: Text(l10n.noCameras))
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 1300 ? 3 : (constraints.maxWidth > 800 ? 2 : 1);
                final width = (constraints.maxWidth - 32 - 12 * (columns - 1)) / columns;
                // The engine scales the preview to the panel's pixels, in steps so that resizing does not
                // resubscribe at every pixel; never above the 640 px a panel needs on a desktop.
                final pixels = width * MediaQuery.devicePixelRatioOf(context);
                final previewWidth = ((pixels / 160).ceil() * 160).clamp(160, 640);
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final camera in cameras)
                        SizedBox(
                          width: width,
                          child: CameraPanel(
                            camera: camera,
                            expanded: !_collapsed.contains(camera),
                            active: !_fullscreen,
                            previewWidth: previewWidth,
                            onOpen: () => _openFullscreen(camera),
                            onToggle: () => setState(
                              () => _collapsed.contains(camera) ? _collapsed.remove(camera) : _collapsed.add(camera),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Keeps the newest preview frame of a camera and measures the preview rate while it is watched.
mixin _PreviewWatcher<T extends StatefulWidget> on State<T> {
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
    final engine = EngineScope.of(context);
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

class CameraPanel extends StatefulWidget {
  const CameraPanel({
    super.key,
    required this.camera,
    required this.expanded,
    required this.onToggle,
    this.active = true,
    this.previewWidth = 640,
    this.onOpen,
  });

  final String camera;
  final bool expanded;

  /// false while the panel is covered; it keeps its last image but stops the preview
  final bool active;
  final int previewWidth;

  /// Opens the camera full screen; the panel pushes the page itself without it
  final VoidCallback? onOpen;
  final VoidCallback onToggle;

  @override
  State<CameraPanel> createState() => _CameraPanelState();
}

class _CameraPanelState extends State<CameraPanel> with _PreviewWatcher<CameraPanel> {
  @override
  String get watchedCamera => widget.camera;
  @override
  double get previewFps => 10;
  @override
  int get previewWidth => widget.previewWidth;

  bool _watching(CameraPanel panel) => panel.expanded && panel.active;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_watching(widget)) startWatching();
  }

  @override
  void didUpdateWidget(CameraPanel old) {
    super.didUpdateWidget(old);
    final watching = _watching(widget);
    if (_watching(old) && (!watching || widget.previewWidth != old.previewWidth)) setState(stopWatching);
    if (watching && (!_watching(old) || widget.previewWidth != old.previewWidth)) startWatching();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = EngineScope.of(context).cameraStatus[widget.camera];
    final current = frame;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('camera-header-${widget.camera}'),
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  _StateDot(status?.state),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: cameraLabel(context, widget.camera),
                        children: [TextSpan(text: '  ${widget.camera}', style: theme.textTheme.bodySmall)],
                      ),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Icon(widget.expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _StatusLine(
              status: status,
              previewRate: widget.expanded ? previewRate : null,
              frameSize: current == null ? null : '${current.width}×${current.height}',
            ),
          ),
          if (widget.expanded)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: current == null
                  ? Center(child: Text(l10n.waitingForImage))
                  : Tooltip(
                      message: l10n.tapToEnlarge,
                      child: GestureDetector(
                        onTap:
                            widget.onOpen ??
                            () => Navigator.of(context)
                                .push(MaterialPageRoute<void>(builder: (_) => CameraFullscreen(camera: widget.camera))),
                        child: LayoutBuilder(
                          // Decoded at the size it is shown, not at the size it was sent
                          builder: (context, constraints) => _StaleFrame(
                            seconds: secondsWithoutFrame,
                            child: LiveJpeg(
                              current.jpeg,
                              key: ValueKey('preview-${widget.camera}'),
                              cacheWidth: _decodeWidth(
                                constraints.maxWidth * MediaQuery.devicePixelRatioOf(context),
                                current.width,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

/// Pixels to decode a frame of [frameWidth] into for a box [boxPixels] wide; null keeps the frame's size.
int? _decodeWidth(double boxPixels, int frameWidth) {
  if (!boxPixels.isFinite) return null;
  final pixels = boxPixels.ceil();
  return pixels < frameWidth ? pixels : null;
}

/// One camera full screen, at a higher resolution, with pinch and wheel zoom.
class CameraFullscreen extends StatefulWidget {
  const CameraFullscreen({super.key, required this.camera});

  final String camera;

  @override
  State<CameraFullscreen> createState() => _CameraFullscreenState();
}

class _CameraFullscreenState extends State<CameraFullscreen> with _PreviewWatcher<CameraFullscreen> {
  @override
  String get watchedCamera => widget.camera;
  @override
  double get previewFps => 15;
  @override
  int get previewWidth => 1280;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    startWatching();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = EngineScope.of(context).cameraStatus[widget.camera];
    final current = frame;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(children: [_StateDot(status?.state), const SizedBox(width: 8), Text(widget.camera)]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _StatusLine(
              status: status,
              previewRate: previewRate,
              frameSize: current == null ? null : '${current.width}×${current.height}',
            ),
          ),
        ),
      ),
      body: current == null
          ? Center(child: Text(l10n.waitingForImage))
          : InteractiveViewer(
              maxScale: 6,
              child: Center(
                child: _StaleFrame(
                  seconds: secondsWithoutFrame,
                  child: LiveJpeg(current.jpeg, key: ValueKey('fullscreen-${widget.camera}')),
                ),
              ),
            ),
    );
  }
}

/// A camera image with a note over it once no new frame came for [seconds], so a frozen image does not look live
class _StaleFrame extends StatelessWidget {
  const _StaleFrame({required this.seconds, required this.child});

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

class _StateDot extends StatelessWidget {
  const _StateDot(this.state);

  /// null before the engine reported the camera
  final String? state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (state) {
      'lost' => (l10n.cameraLost, StatusColors.of(context).bad),
      'degraded' => (l10n.cameraDegraded, StatusColors.of(context).warning),
      'ok' => (l10n.cameraOk, StatusColors.of(context).good),
      _ => (l10n.cameraUnknown, Theme.of(context).disabledColor),
    };
    return Tooltip(
      message: label,
      child: Chip(
        visualDensity: VisualDensity.compact,
        avatar: Icon(Icons.circle, size: 12, color: color),
        label: Text(label),
      ),
    );
  }
}

/// Engine status of a camera and the preview's own rate and size
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status, required this.previewRate, required this.frameSize});

  final EngineCameraStatus? status;
  final double? previewRate;
  final String? frameSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    final s = status;
    final parts = [
      if (s?.effectiveFps != null) l10n.fps(s!.effectiveFps!.toStringAsFixed(1)),
      if (s?.lostFrames != null) '${l10n.lostFrames} ${s!.lostFrames}',
      if (s?.overflowDrops != null) '${l10n.droppedFrames} ${s!.overflowDrops}',
      if (s?.brightness != null) '${l10n.brightness} ${s!.brightness!.toStringAsFixed(0)}',
      if (s?.latencyMs != null) '${l10n.latency} ${s!.latencyMs!.toStringAsFixed(1)} ms',
      if (previewRate != null) '${l10n.preview} ${l10n.fps(previewRate!.toStringAsFixed(1))}',
      ?frameSize,
    ];
    return Text(parts.join('  ·  '), key: const ValueKey('camera-status-line'), style: style);
  }
}
