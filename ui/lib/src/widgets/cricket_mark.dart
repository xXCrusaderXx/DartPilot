import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Cricket's marks drawn as on a chalk board: one a slash, two a cross, three a circled cross. Drawn rather than
/// written, since fonts often lack ✕ and Ⓧ; screen readers hear the count.
class CricketMark extends StatelessWidget {
  const CricketMark(this.marks, {super.key, required this.size, this.color});

  final int marks;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colour = color ?? DefaultTextStyle.of(context).style.color ?? Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: AppLocalizations.of(context).cricketMarksLabel(marks.clamp(0, 3)),
      child: CustomPaint(size: Size.square(size), painter: _MarkPainter(marks, colour)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.marks, this.colour);

  final int marks;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    if (marks <= 0) return;
    final s = size.shortestSide;
    final paint = Paint()
      ..color = colour
      ..strokeWidth = s * 0.12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final inset = s * 0.22;
    canvas.drawLine(Offset(inset, s - inset), Offset(s - inset, inset), paint);
    if (marks >= 2) canvas.drawLine(Offset(inset, inset), Offset(s - inset, s - inset), paint);
    if (marks >= 3) canvas.drawCircle(Offset(s / 2, s / 2), s / 2 - paint.strokeWidth / 2, paint);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.marks != marks || old.colour != colour;
}
