import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/engine_events.dart';
import 'dart_throw.dart';
import 'scoring.dart';
import '../display.dart';
import '../widgets/live_jpeg.dart';
import '../../l10n/app_localizations.dart';
import 'score_text.dart';

/// Interactive dartboard drawn in board coordinates. A tap reports the board point in mm, so manual input goes
/// through the same scorer as engine results.
class Dartboard extends StatelessWidget {
  const Dartboard({
    super.key,
    this.onTap,
    this.throws = const [],
    this.highlights = const [],
    this.geometry = const BoardGeometry(),
    this.image,
  });

  final ValueChanged<BoardPoint>? onTap;
  final List<DartThrow> throws;

  /// Fields to mark, e.g. the fields an uncertain dart may be in
  final List<Score> highlights;
  final BoardGeometry geometry;

  /// The player's real board from the engine, drawn instead of the painted board when there is one
  final BoardImage? image;

  /// Radius drawn around the scoring area for the number ring, in mm
  static const double numberRingMm = 30.0;

  /// Where the projected numbers sit over the real board's number plates
  static const double realNumbersRadiusMm = 208.0;

  @override
  Widget build(BuildContext context) {
    // Also drawn outside the app's localisations, for instance on its own in a test
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    // A painting to the eye; to a screen reader the board, its darts and, where it takes input, what a tap does
    return Semantics(
      label: l10n?.dartboardLabel,
      value: l10n == null ? null : throws.map((t) => t.score.text(l10n)).join(', '),
      hint: onTap == null ? null : l10n?.dartboardTapHint,
      container: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final display = DisplayScope.of(context);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: onTap == null
                  ? null
                  : (details) => onTap!(toBoard(details.localPosition, size, geometry, image: image)),
              child: _withImage(
                context,
                size,
                CustomPaint(
                  size: size,
                  painter: _DartboardPainter(
                    geometry,
                    throws,
                    Theme.of(context).colorScheme,
                    image: image,
                    highlights: highlights,
                    fields: display.boardColours,
                    dartColour: display.dartColour,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The image placed by its board coordinates, the throws on top
  Widget _withImage(BuildContext context, Size size, Widget overlay) {
    final board = image;
    if (board == null) return overlay;
    final scale = scaleFor(size, geometry, image: board);
    final half = board.radiusMm * scale;
    return ClipRect(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: size.width / 2 - half,
            top: size.height / 2 - half,
            width: 2 * half,
            height: 2 * half,
            // A new image comes after every takeout; decoded at the size it is shown.
            child: LiveJpeg(
              board.jpeg,
              key: const ValueKey('board-image'),
              fit: BoxFit.fill,
              cacheWidth: (2 * half * MediaQuery.devicePixelRatioOf(context)).ceil(),
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
  _DartboardPainter(
    this.geometry,
    this.throws,
    this.colors, {
    this.image,
    this.highlights = const [],
    this.fields = BoardColours.classic,
    this.dartColour,
  });

  final BoardGeometry geometry;
  final List<DartThrow> throws;
  final ColorScheme colors;
  final List<Score> highlights;

  /// The real board's image underneath; the painted board is left out then
  final BoardImage? image;

  final BoardColours fields;

  /// The darts' colour, or the accent
  final Color? dartColour;

  bool get drawBoard => image == null;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = Dartboard.scaleFor(size, geometry, image: image);
    final centre = size.center(Offset.zero);
    if (drawBoard) {
      final g = geometry;
      canvas.drawCircle(
        centre,
        (g.doubleOuterRadiusMm + Dartboard.numberRingMm) * scale,
        Paint()..color = fields.darkSingle,
      );

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
          final color = scoringRing
              ? (dark ? fields.darkRing : fields.lightRing)
              : (dark ? fields.darkSingle : fields.lightSingle);
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
      canvas.drawCircle(centre, g.outerBullRadiusMm * scale, Paint()..color = fields.lightRing);
      canvas.drawCircle(centre, g.bullRadiusMm * scale, Paint()..color = fields.darkRing);

      final wire = Paint()
        ..color = const Color(0xFFB0B0B0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, 0.6 * scale);
      for (final radius in g.boundaries) {
        canvas.drawCircle(centre, radius * scale, wire);
      }
    }

    if (!drawBoard) {
      // The projected numbers cover the photographed ones: placed by the calibrated board geometry, they show where
      // the engine puts each sector.
      final plate = Paint()..color = const Color(0xE6141414);
      for (final sector in sectorsClockwiseFromTop) {
        final angle = sectorMiddleDeg(sector, geometry) * math.pi / 180.0;
        canvas.drawCircle(
          centre + Offset(math.cos(angle), -math.sin(angle)) * Dartboard.realNumbersRadiusMm * scale,
          13 * scale,
          plate,
        );
      }
      for (final sector in sectorsClockwiseFromTop) {
        _drawNumber(canvas, centre, scale, sector, radiusMm: Dartboard.realNumbersRadiusMm, sizeMm: 17);
      }
    }

    for (final field in highlights) {
      final path = _fieldPath(field, centre, scale);
      if (path == null) continue;
      canvas.drawPath(path, Paint()..color = colors.primary.withValues(alpha: 0.45));
      canvas.drawPath(
        path,
        Paint()
          ..color = colors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    final dart = dartColour;
    // The earlier darts of the visit in a duller shade of the chosen colour
    final latestColour = dart ?? colors.primary;
    final earlierColour = dart == null ? colors.tertiary : Color.lerp(dart, const Color(0xFF808080), 0.45)!;
    for (var i = 0; i < throws.length; ++i) {
      final point = throws[i].point;
      final position = centre + Offset(point.xMm * scale, -point.yMm * scale);
      final latest = i == throws.length - 1;
      final radius = math.max(4.0, 3.5 * scale);
      // A light halo outside the dark outline keeps a dark dart colour visible on the board's dark fields.
      canvas.drawCircle(
        position,
        radius + 1.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(position, radius, Paint()..color = latest ? latestColour : earlierColour);
      canvas.drawCircle(
        position,
        radius,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  /// The outline of a field on the canvas; null for a miss, which has no field
  Path? _fieldPath(Score field, Offset centre, double scale) {
    final g = geometry;
    Rect circle(double radiusMm) => Rect.fromCircle(center: centre, radius: radiusMm * scale);
    final (inner, outer) = switch (field.ring) {
      Ring.innerBull => (0.0, g.bullRadiusMm),
      Ring.outerBull => (g.bullRadiusMm, g.outerBullRadiusMm),
      Ring.innerSingle => (g.outerBullRadiusMm, g.tripleInnerRadiusMm),
      Ring.triple => (g.tripleInnerRadiusMm, g.tripleOuterRadiusMm),
      Ring.outerSingle => (g.tripleOuterRadiusMm, g.doubleInnerRadiusMm),
      Ring.double => (g.doubleInnerRadiusMm, g.doubleOuterRadiusMm),
      Ring.miss => (0.0, 0.0),
    };
    if (field.ring == Ring.miss) return null;
    if (field.ring == Ring.innerBull || field.ring == Ring.outerBull) {
      return Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(circle(outer))
        ..addOval(circle(inner));
    }
    // Canvas angles run clockwise from +x, board angles counter-clockwise, so the sign flips.
    final start = -(sectorMiddleDeg(field.sector, g) + 9.0) * math.pi / 180.0;
    const sweep = 18.0 * math.pi / 180.0;
    return Path()
      ..arcTo(circle(outer), start, sweep, true)
      ..arcTo(circle(inner), start + sweep, -sweep, false)
      ..close();
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
      old.throws != throws ||
      old.highlights != highlights ||
      old.geometry != geometry ||
      old.colors != colors ||
      old.fields != fields ||
      old.dartColour != dartColour ||
      old.image != image;
}
