import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dart_throw.dart';
import 'scoring.dart';

/// Interactive dartboard drawn in board coordinates. A tap reports the board point in mm, so manual input goes
/// through the same scorer as engine results.
class Dartboard extends StatelessWidget {
  const Dartboard({super.key, this.onTap, this.throws = const [], this.geometry = const BoardGeometry()});

  final ValueChanged<BoardPoint>? onTap;
  final List<DartThrow> throws;
  final BoardGeometry geometry;

  /// Radius drawn around the scoring area for the number ring, in mm
  static const double numberRingMm = 30.0;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onTap == null ? null : (details) => onTap!(toBoard(details.localPosition, size, geometry)),
            child: CustomPaint(size: size, painter: _DartboardPainter(geometry, throws, Theme.of(context).colorScheme)),
          );
        },
      ),
    );
  }

  /// Pixels per mm for a widget of this size
  static double scaleFor(Size size, BoardGeometry geometry) =>
      size.shortestSide / (2 * (geometry.doubleOuterRadiusMm + numberRingMm));

  /// Widget position to board point: origin in the middle, +y up
  static BoardPoint toBoard(Offset position, Size size, BoardGeometry geometry) {
    final scale = scaleFor(size, geometry);
    return BoardPoint((position.dx - size.width / 2) / scale, -(position.dy - size.height / 2) / scale);
  }
}

class _DartboardPainter extends CustomPainter {
  _DartboardPainter(this.geometry, this.throws, this.colors);

  final BoardGeometry geometry;
  final List<DartThrow> throws;
  final ColorScheme colors;

  static const _black = Color(0xFF1B1B1B);
  static const _white = Color(0xFFF1E9D2);
  static const _red = Color(0xFFD03A2B);
  static const _green = Color(0xFF1E8F4E);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = Dartboard.scaleFor(size, geometry);
    final centre = size.center(Offset.zero);
    final g = geometry;
    canvas.drawCircle(centre, (g.doubleOuterRadiusMm + Dartboard.numberRingMm) * scale, Paint()..color = _black);

    // Sectors from the outside in: double, outer single, triple, inner single
    final bands = [
      (g.doubleOuterRadiusMm, true),
      (g.doubleInnerRadiusMm, false),
      (g.tripleOuterRadiusMm, true),
      (g.tripleInnerRadiusMm, false),
    ];
    for (var i = 0; i < 20; ++i) {
      final sector = sectorsClockwiseFromTop[i];
      final dark = i.isEven;
      // Canvas angles run clockwise from +x, board angles counter-clockwise, so the sign flips.
      final start = -(sectorMiddleDeg(sector, g) + 9.0) * math.pi / 180.0;
      const sweep = 18.0 * math.pi / 180.0;
      for (final (radius, scoringRing) in bands) {
        final color = scoringRing ? (dark ? _red : _green) : (dark ? _black : _white);
        canvas.drawArc(
          Rect.fromCircle(center: centre, radius: radius * scale),
          start,
          sweep,
          true,
          Paint()..color = color,
        );
      }
      _drawNumber(canvas, centre, scale, sector);
    }
    canvas.drawCircle(centre, g.outerBullRadiusMm * scale, Paint()..color = _green);
    canvas.drawCircle(centre, g.bullRadiusMm * scale, Paint()..color = _red);

    final wire = Paint()
      ..color = const Color(0xFFB0B0B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 0.6 * scale);
    for (final radius in g.boundaries) {
      canvas.drawCircle(centre, radius * scale, wire);
    }

    for (var i = 0; i < throws.length; ++i) {
      final point = throws[i].point;
      final position = centre + Offset(point.xMm * scale, -point.yMm * scale);
      final latest = i == throws.length - 1;
      canvas.drawCircle(
        position,
        math.max(4.0, 3.5 * scale),
        Paint()..color = latest ? colors.primary : colors.tertiary,
      );
      canvas.drawCircle(
        position,
        math.max(4.0, 3.5 * scale),
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawNumber(Canvas canvas, Offset centre, double scale, int sector) {
    final angle = sectorMiddleDeg(sector, geometry) * math.pi / 180.0;
    final radius = (geometry.doubleOuterRadiusMm + Dartboard.numberRingMm / 2) * scale;
    final painter = TextPainter(
      text: TextSpan(
        text: '$sector',
        style: TextStyle(color: Colors.white, fontSize: 13 * scale, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final position = centre + Offset(radius * math.cos(angle), -radius * math.sin(angle));
    painter.paint(canvas, position - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_DartboardPainter old) => old.throws != throws || old.geometry != geometry || old.colors != colors;
}
