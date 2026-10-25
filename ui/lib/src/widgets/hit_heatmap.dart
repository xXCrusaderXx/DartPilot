import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../board/scoring.dart';

/// The board with every field coloured by how often it was hit: the hit-rate board of the statistics (#117).
/// Fields come from the stored darts' ring and sector, so inner and outer singles show apart.
class HitHeatmap extends StatelessWidget {
  const HitHeatmap({super.key, required this.hits, this.geometry = const BoardGeometry()});

  /// Darts per ring and sector; bulls and misses use sector 0
  final Map<(Ring, int), int> hits;
  final BoardGeometry geometry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _HeatmapPainter(
          hits: hits,
          geometry: geometry,
          empty: theme.colorScheme.surfaceContainerHighest,
          hot: theme.colorScheme.primary,
          wire: theme.colorScheme.outlineVariant,
          text: theme.textTheme.labelMedium!.copyWith(color: theme.colorScheme.onSurface),
          countText: theme.textTheme.labelSmall!,
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.hits,
    required this.geometry,
    required this.empty,
    required this.hot,
    required this.wire,
    required this.text,
    required this.countText,
  });

  final Map<(Ring, int), int> hits;
  final BoardGeometry geometry;
  final Color empty;
  final Color hot;
  final Color wire;
  final TextStyle text;
  final TextStyle countText;

  /// Room around the double ring for the sector numbers, in mm
  static const double numbersMm = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final centre = size.center(Offset.zero);
    final scale = size.shortestSide / 2 / (g.doubleOuterRadiusMm + numbersMm);
    final most = hits.entries.where((e) => e.key.$1 != Ring.miss).fold(0, (m, e) => math.max(m, e.value));
    Color colour(int count) {
      if (count == 0 || most == 0) return empty;
      // Square root, so that fields hit a few times stand out next to the favourite one
      return Color.lerp(empty, hot, 0.2 + 0.8 * math.sqrt(count / most))!;
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = wire
      ..strokeWidth = 1;
    final bands = [
      (Ring.innerSingle, g.outerBullRadiusMm, g.tripleInnerRadiusMm),
      (Ring.triple, g.tripleInnerRadiusMm, g.tripleOuterRadiusMm),
      (Ring.outerSingle, g.tripleOuterRadiusMm, g.doubleInnerRadiusMm),
      (Ring.double, g.doubleInnerRadiusMm, g.doubleOuterRadiusMm),
    ];
    for (var sector = 1; sector <= 20; ++sector) {
      final middle = sectorMiddleDeg(sector, g);
      for (final (ring, inner, outer) in bands) {
        final path = _wedge(centre, inner * scale, outer * scale, middle);
        final count = hits[(ring, sector)] ?? 0;
        canvas.drawPath(path, Paint()..color = colour(count));
        canvas.drawPath(path, stroke);
        if (count > 0) _label(canvas, '$count', _at(centre, (inner + outer) / 2 * scale, middle), countText, count);
      }
      _label(canvas, '$sector', _at(centre, (g.doubleOuterRadiusMm + numbersMm / 2) * scale, middle), text, null);
    }
    for (final (ring, radius) in [(Ring.outerBull, g.outerBullRadiusMm), (Ring.innerBull, g.bullRadiusMm)]) {
      final count = hits[(ring, 0)] ?? 0;
      canvas.drawCircle(centre, radius * scale, Paint()..color = colour(count));
      canvas.drawCircle(centre, radius * scale, stroke);
    }
    final bulls = (hits[(Ring.outerBull, 0)] ?? 0) + (hits[(Ring.innerBull, 0)] ?? 0);
    if (bulls > 0) _label(canvas, '$bulls', centre, countText, bulls);
  }

  Offset _at(Offset centre, double radius, double angleDeg) {
    final a = angleDeg * math.pi / 180;
    // Board angles turn counter-clockwise with y up; the screen's y points down.
    return centre + Offset(radius * math.cos(a), -radius * math.sin(a));
  }

  Path _wedge(Offset centre, double inner, double outer, double middleDeg) {
    final start = -(middleDeg + 9) * math.pi / 180;
    const sweep = 18 * math.pi / 180;
    return Path()
      ..arcTo(Rect.fromCircle(center: centre, radius: outer), start, sweep, true)
      ..arcTo(Rect.fromCircle(center: centre, radius: inner), start + sweep, -sweep, false)
      ..close();
  }

  void _label(Canvas canvas, String value, Offset at, TextStyle style, int? count) {
    final contrast = count == null
        ? style
        : style.copyWith(
            color: ThemeData.estimateBrightnessForColor(Color.lerp(empty, hot, 0.6)!) == Brightness.dark
                ? Colors.white
                : Colors.black,
          );
    final painter = TextPainter(
      text: TextSpan(text: value, style: contrast),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => old.hits != hits || old.geometry != geometry || old.hot != hot;
}
