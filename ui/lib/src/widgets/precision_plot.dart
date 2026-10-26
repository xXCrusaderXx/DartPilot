import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../board/dart_throw.dart';
import '../board/scoring.dart';
import '../stats/precision.dart';

/// The board around one target, zoomed in (#125): the wires, the darts, their mean and their 1-sigma ellipse.
class PrecisionPlot extends StatelessWidget {
  const PrecisionPlot({
    super.key,
    required this.target,
    required this.points,
    this.windowMm = 45,
    this.geometry = const BoardGeometry(),
  });

  final PrecisionTarget target;
  final List<BoardPoint> points;

  /// Half the width of the area shown, around the target
  final double windowMm;
  final BoardGeometry geometry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: _PrecisionPainter(
            centre: target.centre(geometry),
            points: points,
            spread: Spread.of(points, target.centre(geometry)),
            windowMm: windowMm,
            geometry: geometry,
            colors: colors,
          ),
        ),
      ),
    );
  }
}

class _PrecisionPainter extends CustomPainter {
  _PrecisionPainter({
    required this.centre,
    required this.points,
    required this.spread,
    required this.windowMm,
    required this.geometry,
    required this.colors,
  });

  final BoardPoint centre;
  final List<BoardPoint> points;
  final Spread? spread;
  final double windowMm;
  final BoardGeometry geometry;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / (2 * windowMm);
    final middle = size.center(Offset.zero);
    Offset toCanvas(double xMm, double yMm) => middle + Offset((xMm - centre.xMm) * scale, -(yMm - centre.yMm) * scale);

    canvas.drawRect(Offset.zero & size, Paint()..color = colors.surfaceContainerHighest);

    final wire = Paint()
      ..color = colors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final boardCentre = toCanvas(0, 0);
    for (final radius in geometry.boundaries) {
      canvas.drawCircle(boardCentre, radius * scale, wire);
    }
    for (final sector in sectorsClockwiseFromTop) {
      final angle = (sectorMiddleDeg(sector, geometry) + 9) * math.pi / 180;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final from = direction * geometry.outerBullRadiusMm;
      final to = direction * geometry.doubleOuterRadiusMm;
      canvas.drawLine(toCanvas(from.dx, from.dy), toCanvas(to.dx, to.dy), wire);
    }

    final cross = Paint()
      ..color = colors.onSurface
      ..strokeWidth = 1.5;
    canvas.drawLine(middle - const Offset(8, 0), middle + const Offset(8, 0), cross);
    canvas.drawLine(middle - const Offset(0, 8), middle + const Offset(0, 8), cross);

    final dot = Paint()..color = colors.tertiary;
    final ring = Paint()
      ..color = colors.onTertiary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final p in points) {
      final position = toCanvas(p.xMm, p.yMm);
      canvas.drawCircle(position, 4, dot);
      canvas.drawCircle(position, 4, ring);
    }

    final s = spread;
    if (s == null) return;
    final mean = toCanvas(centre.xMm + s.offsetXMm, centre.yMm + s.offsetYMm);
    final (:majorMm, :minorMm, :angleDeg) = s.ellipse;
    canvas.save();
    canvas.translate(mean.dx, mean.dy);
    // Canvas y points down, so the board angle turns the other way.
    canvas.rotate(-angleDeg * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 2 * majorMm * scale, height: 2 * minorMm * scale),
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
    canvas.drawCircle(mean, 5, Paint()..color = colors.primary);
  }

  @override
  bool shouldRepaint(_PrecisionPainter old) =>
      old.points != points || old.centre != centre || old.colors != colors || old.geometry != geometry;
}
