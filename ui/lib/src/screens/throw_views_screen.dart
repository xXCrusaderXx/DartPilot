import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import 'diagnosis_screen.dart';

/// The camera views of one throw (#129): each camera's crop before and after it, with the tip the camera found, the
/// dart's axis and the located point. Pops with true when the player wants to correct the dart.
class ThrowViewsScreen extends StatefulWidget {
  const ThrowViewsScreen({super.key, required this.throwId, required this.label, this.canCorrect = false});

  final String throwId;

  /// The dart's score as the game counts it, for the title
  final String label;

  /// Offers to correct the dart, from a game in progress
  final bool canCorrect;

  @override
  State<ThrowViewsScreen> createState() => _ThrowViewsScreenState();
}

class _ThrowViewsScreenState extends State<ThrowViewsScreen> {
  String? _error;
  bool _requested = false;
  bool _after = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = EngineScope.of(context);
    if (_requested || !engine.isConnected || engine.throwViews.containsKey(widget.throwId)) return;
    _requested = true;
    engine.requestThrowViews(widget.throwId).then((error) {
      if (mounted && error != null) setState(() => _error = error);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final engine = EngineScope.of(context);
    final views = engine.throwViews[widget.throwId];
    final Widget body;
    if (views != null) {
      final cameras = engine.hello?.cameras ?? const <String>[];
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l10n.throwViewBefore)),
                ButtonSegment(value: true, label: Text(l10n.throwViewAfter)),
              ],
              selected: {_after},
              onSelectionChanged: (s) => setState(() => _after = s.first),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final view in views.cameras)
                SizedBox(
                  width: 300,
                  child: _CameraView(view: view, name: cameraName(context, cameras, view.camera), after: _after),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.throwViewLegend, style: theme.textTheme.bodySmall),
        ],
      );
    } else {
      final message = !engine.isConnected
          ? l10n.throwViewNoEngine
          : _error == 'not_available'
          ? l10n.throwViewNotAvailable
          : _error != null
          ? l10n.throwViewFailed(_error!)
          : null;
      body = Center(
        child: message == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(message, key: const ValueKey('throw-views-message'), textAlign: TextAlign.center),
              ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.throwViewTitle(widget.label))),
      body: body,
      bottomNavigationBar: widget.canCorrect
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  key: const ValueKey('throw-views-correct'),
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.edit_location_alt),
                  label: Text(l10n.throwViewCorrect),
                ),
              ),
            )
          : null,
    );
  }
}

class _CameraView extends StatelessWidget {
  const _CameraView({required this.view, required this.name, required this.after});

  final ThrowView view;
  final String name;
  final bool after;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final jpeg = after ? view.after : view.before;
    final reason = switch (view.reason) {
      'not_seen' => l10n.throwViewNotSeen,
      'cut' => l10n.throwViewCut,
      'disagrees' => l10n.throwViewDisagrees,
      _ => view.reason,
    };
    final distance = view.planeDistanceMm;
    return Card(
      key: ValueKey('throw-view-${view.camera}'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (jpeg != null && view.imageSizePx.width > 0 && view.imageSizePx.height > 0)
            AspectRatio(
              aspectRatio: view.imageSizePx.width / view.imageSizePx.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(jpeg, fit: BoxFit.fill, gaplessPlayback: true),
                  if (after)
                    CustomPaint(
                      painter: _OverlayPainter(view, theme.colorScheme),
                      key: ValueKey('throw-view-overlay-${view.camera}'),
                    ),
                ],
              ),
            ),
          ListTile(
            leading: Icon(
              view.used ? Icons.check_circle : Icons.cancel_outlined,
              color: view.used ? theme.colorScheme.primary : theme.colorScheme.error,
            ),
            title: Text(name),
            subtitle: Text(
              [
                if (view.used) l10n.throwViewUsed else reason.isEmpty ? l10n.throwViewNotUsed : reason,
                if (distance != null)
                  l10n.throwViewPlaneDistance(
                    NumberFormat.decimalPatternDigits(locale: l10n.localeName, decimalDigits: 1).format(distance),
                  ),
              ].join('  ·  '),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dart's axis as a line, the tip the camera found as a ring, and the located point as a cross, scaled from crop
/// pixels to the size shown
class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.view, this.colors);

  final ThrowView view;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / view.imageSizePx.width, sy = size.height / view.imageSizePx.height;
    Offset scaled(Offset p) => Offset(p.dx * sx, p.dy * sy);
    final axis = view.axisPx;
    if (axis != null) {
      canvas.drawLine(
        scaled(axis.$1),
        scaled(axis.$2),
        Paint()
          ..color = colors.tertiary
          ..strokeWidth = 2,
      );
    }
    final tip = view.tipPx;
    if (tip != null) {
      canvas.drawCircle(
        scaled(tip),
        6,
        Paint()
          ..color = colors.tertiary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final located = view.locatedPx;
    if (located != null) {
      final c = scaled(located);
      final paint = Paint()
        ..color = colors.primary
        ..strokeWidth = 2.5;
      canvas.drawLine(c - const Offset(7, 7), c + const Offset(7, 7), paint);
      canvas.drawLine(c - const Offset(7, -7), c + const Offset(7, -7), paint);
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.view != view || old.colors != colors;
}
