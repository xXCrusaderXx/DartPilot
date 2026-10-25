import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The 3-dart average of each game, oldest left, as a line with a dot per game (#117)
class AverageTrend extends StatelessWidget {
  const AverageTrend({super.key, required this.averages});

  /// One average per game, oldest first
  final List<double> averages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 160,
      child: CustomPaint(
        painter: _TrendPainter(
          averages: averages,
          line: theme.colorScheme.primary,
          grid: theme.colorScheme.outlineVariant,
          label: theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.averages, required this.line, required this.grid, required this.label});

  final List<double> averages;
  final Color line;
  final Color grid;
  final TextStyle label;

  static const double axisPx = 32;

  @override
  void paint(Canvas canvas, Size size) {
    if (averages.isEmpty) return;
    // Rounded to tens with some room, so a steady player's line is not a flat stroke at the top
    final low = (averages.reduce(math.min) / 10).floor() * 10.0;
    final high = math.max(low + 10, (averages.reduce(math.max) / 10).ceil() * 10.0);
    final plot = Rect.fromLTRB(axisPx, 8, size.width - 8, size.height - 8);
    double y(double v) => plot.bottom - (v - low) / (high - low) * plot.height;
    double x(int i) => averages.length == 1 ? plot.center.dx : plot.left + i / (averages.length - 1) * plot.width;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [low, (low + high) / 2, high]) {
      canvas.drawLine(Offset(plot.left, y(v)), Offset(plot.right, y(v)), gridPaint);
      final text = TextPainter(
        text: TextSpan(text: v.toStringAsFixed(0), style: label),
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
  bool shouldRepaint(_TrendPainter old) => old.averages != averages || old.line != line;
}
