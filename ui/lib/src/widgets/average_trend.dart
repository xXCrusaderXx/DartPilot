import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The 3-dart average of each game, oldest left, as a line with a dot per game (#117); also the weekly spread in mm
/// (#125)
class AverageTrend extends StatelessWidget {
  const AverageTrend({super.key, required this.averages, this.unit, this.from, this.to, this.height = 160});

  /// One average per game, oldest first
  final List<double> averages;

  /// Written after the values on the axis, e.g. "mm"
  final String? unit;

  /// When the first and the last value were made, written under the line's ends
  final String? from;
  final String? to;

  /// The line's height; small for a trend beside other figures
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _TrendPainter(
              averages: averages,
              unit: unit,
              line: theme.colorScheme.primary,
              grid: theme.colorScheme.outlineVariant,
              label: label,
            ),
            size: Size.infinite,
          ),
        ),
        if (from != null || to != null)
          Padding(
            padding: EdgeInsets.only(left: _TrendPainter.axisPx(unit)),
            child: Row(
              children: [
                Text(from ?? '', style: label),
                const Spacer(),
                Text(to ?? '', style: label),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.averages, this.unit, required this.line, required this.grid, required this.label});

  final List<double> averages;
  final String? unit;
  final Color line;
  final Color grid;
  final TextStyle label;

  /// Room left of the line for the values
  static double axisPx(String? unit) => unit == null ? 32 : 56;

  @override
  void paint(Canvas canvas, Size size) {
    if (averages.isEmpty) return;
    // Rounded to tens with some room, so a steady player's line is not a flat stroke at the top
    final low = (averages.reduce(math.min) / 10).floor() * 10.0;
    final high = math.max(low + 10, (averages.reduce(math.max) / 10).ceil() * 10.0);
    final plot = Rect.fromLTRB(axisPx(unit), 8, size.width - 8, size.height - 8);
    double y(double v) => plot.bottom - (v - low) / (high - low) * plot.height;
    double x(int i) => averages.length == 1 ? plot.center.dx : plot.left + i / (averages.length - 1) * plot.width;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [low, (low + high) / 2, high]) {
      canvas.drawLine(Offset(plot.left, y(v)), Offset(plot.right, y(v)), gridPaint);
      final text = TextPainter(
        text: TextSpan(text: unit == null ? v.toStringAsFixed(0) : '${v.toStringAsFixed(0)} $unit', style: label),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(plot.left - text.width - 6, y(v) - text.height / 2));
    }
    final path = Path();
    for (var i = 0; i < averages.length; ++i) {
      final p = Offset(x(i), y(averages[i]));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < averages.length; ++i) {
      canvas.drawCircle(Offset(x(i), y(averages[i])), 3.5, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.averages != averages || old.line != line || old.unit != unit;
}
