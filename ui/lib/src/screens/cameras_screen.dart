import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';

/// Live images of the engine's cameras with their state.
class CamerasScreen extends StatelessWidget {
  const CamerasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = EngineScope.of(context);
    final cameras = engine.hello?.cameras ?? const <String>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cameras)),
      body: cameras.isEmpty
          ? Center(child: Text(l10n.noCameras))
          : LayoutBuilder(
              builder: (context, constraints) => GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: constraints.maxWidth > 1100 ? 3 : (constraints.maxWidth > 700 ? 2 : 1),
                childAspectRatio: 16 / 10,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [for (final camera in cameras) CameraTile(camera: camera)],
              ),
            ),
    );
  }
}

/// One camera: subscribes to its preview while visible and shows the newest image.
class CameraTile extends StatefulWidget {
  const CameraTile({super.key, required this.camera});

  final String camera;

  @override
  State<CameraTile> createState() => _CameraTileState();
}

class _CameraTileState extends State<CameraTile> {
  EngineConnection? _engine;
  StreamSubscription<PreviewFrame>? _subscription;
  PreviewFrame? _frame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = EngineScope.of(context);
    if (identical(engine, _engine)) return;
    _stop();
    _engine = engine;
    _subscription = engine.previews.where((f) => f.camera == widget.camera).listen((f) => setState(() => _frame = f));
    engine.subscribePreview(widget.camera);
  }

  void _stop() {
    _subscription?.cancel();
    _engine?.unsubscribePreview(widget.camera);
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = EngineScope.of(context).cameraStates[widget.camera] ?? 'ok';
    final (label, color) = switch (state) {
      'lost' => (l10n.cameraLost, theme.colorScheme.error),
      'degraded' => (l10n.cameraDegraded, Colors.orange),
      _ => (l10n.cameraOk, Colors.green),
    };
    final frame = _frame;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          frame == null
              ? Center(child: Text(l10n.waitingForImage))
              : Image.memory(
                  frame.jpeg,
                  key: ValueKey('preview-${widget.camera}'),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
          Positioned(
            left: 8,
            top: 8,
            child: Chip(
              avatar: Icon(Icons.circle, size: 12, color: color),
              label: Text('${widget.camera} · $label'),
            ),
          ),
        ],
      ),
    );
  }
}
