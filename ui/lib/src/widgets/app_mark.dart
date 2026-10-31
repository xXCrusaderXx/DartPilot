import 'package:flutter/material.dart';

/// The DartPilot icon, drawn from its source (assets/icon/dartpilot-foreground.svg) on the dark rounded square of the
/// app icon: the measuring ring, the three camera positions and the dart flight pointing at the impact point
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _AppMarkPainter()),
  );
}

class _AppMarkPainter extends CustomPainter {
  static const _ink = Color(0xff0f1216);
  static const _light = Color(0xff7dd3fc);
  static const _sky = Color(0xff38bdf8);
  static const _deep = Color(0xff0284c7);

  @override
  void paint(Canvas canvas, Size size) {
    // The source is drawn on 512 units; the icon's background is a rounded square with a soft vertical gradient.
    canvas.scale(size.width / 512);
    const square = Rect.fromLTWH(0, 0, 512, 512);
    canvas.drawRRect(
      RRect.fromRectAndRadius(square, const Radius.circular(112)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff222b3a), _ink],
        ).createShader(square),
    );
    canvas
      ..translate(256, 256)
      ..scale(0.8)
      ..translate(-256, -256);
    canvas.drawCircle(
      const Offset(256, 256),
      164,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = _sky.withValues(alpha: 0.6),
    );
    for (final c in const [Offset(256, 92), Offset(114, 338), Offset(398, 338)]) {
      canvas
        ..drawCircle(c, 20, Paint()..color = _ink)
        ..drawCircle(
          c,
          20,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10
            ..color = _light,
        );
    }
    const flight = Rect.fromLTRB(166, 150, 346, 338);
    Path half(double side) => Path()
      ..moveTo(256, 150)
      ..cubicTo(256 + 42 * side, 150, 256 + 80 * side, 168, 256 + 88 * side, 204)
      ..cubicTo(256 + 90 * side, 216, 256 + 86 * side, 228, 256 + 78 * side, 240)
      ..lineTo(256 + 12 * side, 330)
      ..lineTo(256, 338)
      ..close();
    Paint gradient(Color top, Color bottom) => Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(flight);
    canvas
      ..drawPath(half(1), gradient(_sky, _deep))
      ..drawPath(half(-1), gradient(_light, _sky))
      ..drawPath(
        Path()
          ..moveTo(247, 336)
          ..lineTo(265, 336)
          ..lineTo(256, 404)
          ..close(),
        Paint()..color = _light,
      )
      ..drawCircle(const Offset(256, 412), 9, Paint()..color = const Color(0xffe0f7ff));
  }

  @override
  bool shouldRepaint(_AppMarkPainter oldDelegate) => false;
}
