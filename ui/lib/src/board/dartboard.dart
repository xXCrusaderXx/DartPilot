import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/engine_events.dart';
import 'dart_throw.dart';
import 'scoring.dart';

/// Interactive dartboard drawn in board coordinates. A tap reports the board point in mm, so manual input goes
/// through the same scorer as engine results.
class Dartboard extends StatelessWidget {
  const Dartboard({super.key, this.onTap, this.throws = const [], this.geometry = const BoardGeometry(), this.image});

  final ValueChanged<BoardPoint>? onTap;
  final List<DartThrow> throws;
  final BoardGeometry geometry;

  /// The player's real board from the engine, drawn instead of the painted board when there is one
  final BoardImage? image;

  /// Radius drawn around the scoring area for the number ring, in mm
  static const double numberRingMm = 30.0;

  /// The real board's image stays sharp this far beyond the outer double wire
  static const double sharpMarginMm = 2.0;

  /// Where the drawn numbers sit over the real board's blurred number ring
  static const double realNumbersRadiusMm = 196.0;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onTap == null
                ? null
                : (details) => onTap!(toBoard(details.localPosition, size, geometry, image: image)),
            child: _withImage(
              size,
              CustomPaint(
                size: size,
                painter: _DartboardPainter(geometry, throws, Theme.of(context).colorScheme, image: image),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The image placed by its board coordinates, the throws on top
  Widget _withImage(Size size, Widget overlay) {
    final board = image;
    if (board == null) return overlay;
    final scale = scaleFor(size, geometry, image: board);
    final half = board.radiusMm * scale;
    return ClipRect(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // The number ring and the surround stand in front of the playing surface, so the cameras put them in different
          // places and the image doubles them: shown blurred and darkened, with drawn numbers on top.
          Positioned(
            left: size.width / 2 - half,
            top: size.height / 2 - half,
            width: 2 * half,
            height: 2 * half,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 6 * scale, sigmaY: 6 * scale),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Color(0x99000000), BlendMode.srcATop),
                child: Image.memory(board.jpeg, fit: BoxFit.fill, gaplessPlayback: true),
              ),
            ),
          ),
          // The playing surface itself is in the projection plane: sharp up to the outer double wire.
          Positioned(
            left: size.width / 2 - half,
            top: size.height / 2 - half,
            width: 2 * half,
            height: 2 * half,
            child: ClipOval(
              clipper: _CircleClipper((geometry.doubleOuterRadiusMm + sharpMarginMm) * scale),
              child: Image.memory(
                board.jpeg,
                key: const ValueKey('board-image'),
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
          ),
          overlay,
        ],
      ),
    );
  }

  /// Pixels per mm for a widget of this size
  /// With the real board's [image] the whole image is shown, the board with its number ring and surround; the
  /// drawn board shows the scoring area and a narrow number ring.
  static double scaleFor(Size size, BoardGeometry geometry, {BoardImage? image}) =>
      size.shortestSide / (2 * (image?.radiusMm ?? geometry.doubleOuterRadiusMm + numberRingMm));

  /// Widget position to board point: origin in the middle, +y up
  static BoardPoint toBoard(Offset position, Size size, BoardGeometry geometry, {BoardImage? image}) {
    final scale = scaleFor(size, geometry, image: image);
    return BoardPoint((position.dx - size.width / 2) / scale, -(position.dy - size.height / 2) / scale);
  }
}

class _DartboardPainter extends CustomPainter {
  _DartboardPainter(this.geometry, this.throws, this.colors, {this.image});

  final BoardGeometry geometry;
  final List<DartThrow> throws;
  final ColorScheme colors;

  /// The real board's image underneath; the painted board is left out then
  final BoardImage? image;

  bool get drawBoard => image == null;

  static const _black = Color(0xFF1B1B1B);
  static const _white = Color(0xFFF1E9D2);
  static const _red = Color(0xFFD03A2B);
  static const _green = Color(0xFF1E8F4E);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = Dartboard.scaleFor(size, geometry, image: image);
    final centre = size.center(Offset.zero);
    if (drawBoard) {
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
    }

    if (!drawBoard) {
      for (final sector in sectorsClockwiseFromTop) {
        _drawNumber(canvas, centre, scale, sector, radiusMm: Dartboard.realNumbersRadiusMm, sizeMm: 17);
      }
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

  void _drawNumber(Canvas canvas, Offset centre, double scale, int sector, {double? radiusMm, double sizeMm = 13}) {
    final angle = sectorMiddleDeg(sector, geometry) * math.pi / 180.0;
    final radius = (radiusMm ?? geometry.doubleOuterRadiusMm + Dartboard.numberRingMm / 2) * scale;
    final painter = TextPainter(
      text: TextSpan(
        text: '$sector',
        style: TextStyle(
          color: Colors.white,
          fontSize: sizeMm * scale,
          fontWeight: FontWeight.w600,
          shadows: const [Shadow(blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final position = centre + Offset(radius * math.cos(angle), -radius * math.sin(angle));
    painter.paint(canvas, position - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_DartboardPainter old) =>
      old.throws != throws || old.geometry != geometry || old.colors != colors || old.image != image;
}

class _CircleClipper extends CustomClipper<Rect> {
  _CircleClipper(this.radius);

  final double radius;

  @override
  Rect getClip(Size size) => Rect.fromCircle(center: size.center(Offset.zero), radius: radius);

  @override
  bool shouldReclip(_CircleClipper old) => old.radius != radius;
}
