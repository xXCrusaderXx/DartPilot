import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../display.dart';
import '../theme.dart';

/// The moments a game screen celebrates, such as a 180 or a checkout; each [show] plays once.
class Celebrations extends ChangeNotifier {
  String? text;

  /// Whether the moment earns the large plate where the player chose full celebrations; a smaller one, such as a
  /// checkout under 100, gets the small one
  bool big = true;
  int _count = 0;

  void show(String text, {bool big = true}) {
    this.text = text;
    this.big = big;
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

  static const Duration _full = Duration(milliseconds: 1500);
  static const Duration _subtle = Duration(milliseconds: 1400);
}

/// Plays each of [celebrations] over [child], the score panel, as strongly as the player chose: a large plate that
/// fades in and settles, a small one that fades in at the top, or nothing. Where the system asks for less motion, the
/// plate shows without moving. Taps pass through.
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
    _controller.duration = celebration == Celebration.full && widget.celebrations.big
        ? Celebrations._full
        : Celebrations._subtle;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final display = DisplayScope.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Under the large plate the score fades, so the plate is never read together with the figures below it
        AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) {
            final plate =
                widget.celebrations.text != null &&
                _controller.isAnimating &&
                display.celebration == Celebration.full &&
                widget.celebrations.big;
            if (!plate) return child!;
            final still = MediaQuery.disableAnimationsOf(context);
            final shown = still ? 1.0 : _opacity(_controller.value, fadeIn: 0.1, fadeOut: 0.25);
            return Opacity(opacity: 1 - 0.85 * shown, child: child);
          },
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final text = widget.celebrations.text;
                if (text == null || !_controller.isAnimating) return const SizedBox.shrink();
                return display.celebration == Celebration.full && widget.celebrations.big
                    ? _full(context, text, _controller.value)
                    : _subtle(context, text, _controller.value);
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
    // A dark plate with yellow figures, as a TV graphic: it stands apart from the yellow block of the player at the
    // oche and from light and dark surfaces alike.
    const plate = AppColors.background;
    const figures = AppColors.warning;
    final scale = still ? 1.0 : 0.92 + 0.08 * Curves.easeOutCubic.transform((t / 0.2).clamp(0, 1));
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth * 0.22, constraints.maxHeight * 0.3).clamp(40, 150).toDouble();
        return Align(
          alignment: const Alignment(0, -0.35),
          child: Opacity(
            opacity: still ? 1 : _opacity(t, fadeIn: 0.1, fadeOut: 0.25),
            // A long text such as a checkout shrinks to the panel rather than breaking into lines
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  key: const ValueKey('celebration'),
                  padding: EdgeInsets.symmetric(horizontal: size * 0.4, vertical: size * 0.08),
                  decoration: BoxDecoration(
                    color: plate,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: figures, width: 3),
                    boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8))],
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      text,
                      style: scoreStyle(Theme.of(context).textTheme.displayLarge)
                          ?.copyWith(color: figures, fontWeight: FontWeight.w700, fontSize: size, height: 1.1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _subtle(BuildContext context, String text, double t) {
    final still = MediaQuery.disableAnimationsOf(context);
    final palette = AppPalette.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        // Over the panel's top line, clear of the name and score below it
        padding: const EdgeInsets.only(top: 2),
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
