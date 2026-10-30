import 'package:flutter/material.dart';

import '../display.dart';
import '../theme.dart';

/// The moments a game screen celebrates, such as a 180 or a checkout; each [show] plays once.
class Celebrations extends ChangeNotifier {
  String? text;
  int _count = 0;

  void show(String text) {
    this.text = text;
    ++_count;
    notifyListeners();
  }

  /// How long a celebration plays, so what follows it can wait: nothing when it is off or the system asks for less
  /// motion
  static Duration playTime(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
    return switch (DisplayScope.of(context).celebration) {
      Celebration.full => _full,
      Celebration.subtle => _subtle,
      Celebration.off => Duration.zero,
    };
  }

  static const Duration _full = Duration(milliseconds: 1800);
  static const Duration _subtle = Duration(milliseconds: 1400);
}

/// Plays each of [celebrations] over [child] as strongly as the player chose: a large banner that springs in, a small
/// one that fades in at the top, or nothing. Where the system asks for less motion, the banner shows without moving.
/// Taps pass through to the board below.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({super.key, required this.celebrations, required this.child});

  final Celebrations celebrations;
  final Widget child;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    widget.celebrations.addListener(_play);
    _shown = widget.celebrations._count;
  }

  @override
  void didUpdateWidget(CelebrationOverlay old) {
    super.didUpdateWidget(old);
    if (!identical(old.celebrations, widget.celebrations)) {
      old.celebrations.removeListener(_play);
      widget.celebrations.addListener(_play);
    }
  }

  @override
  void dispose() {
    widget.celebrations.removeListener(_play);
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    if (widget.celebrations._count == _shown) return;
    _shown = widget.celebrations._count;
    final celebration = DisplayScope.of(context).celebration;
    if (celebration == Celebration.off) return;
    _controller.duration = celebration == Celebration.full ? Celebrations._full : Celebrations._subtle;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final display = DisplayScope.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final text = widget.celebrations.text;
                if (text == null || !_controller.isAnimating) return const SizedBox.shrink();
                return display.celebration == Celebration.subtle
                    ? _subtle(context, text, _controller.value)
                    : _full(context, text, _controller.value);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Rises to full opacity over the first part of [t] and fades over the last
  double _opacity(double t, {required double fadeIn, required double fadeOut}) {
    if (t < fadeIn) return t / fadeIn;
    if (t > 1 - fadeOut) return (1 - t) / fadeOut;
    return 1;
  }

  Widget _full(BuildContext context, String text, double t) {
    final still = MediaQuery.disableAnimationsOf(context);
    final palette = AppPalette.of(context);
    final size = MediaQuery.sizeOf(context);
    final scale = still ? 1.0 : 0.6 + 0.4 * Curves.elasticOut.transform((t / 0.4).clamp(0, 1));
    return Center(
      child: Opacity(
        opacity: still ? 1 : _opacity(t, fadeIn: 0.1, fadeOut: 0.25),
        child: Transform.scale(
          scale: scale,
          child: Container(
            key: const ValueKey('celebration'),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            decoration: BoxDecoration(color: palette.highlight, borderRadius: BorderRadius.circular(24)),
            child: Semantics(
              liveRegion: true,
              child: Text(
                text,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: palette.onHighlight,
                  fontWeight: FontWeight.w900,
                  fontSize: (size.shortestSide * 0.18).clamp(48, 160).toDouble(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _subtle(BuildContext context, String text, double t) {
    final still = MediaQuery.disableAnimationsOf(context);
    final palette = AppPalette.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Opacity(
          opacity: still ? 1 : _opacity(t, fadeIn: 0.15, fadeOut: 0.3),
          child: Container(
            key: const ValueKey('celebration'),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: palette.surfaceRaised,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: palette.highlight, width: 2),
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: palette.text, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
