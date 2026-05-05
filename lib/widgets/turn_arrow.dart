// lib/widgets/turn_arrow.dart
import 'package:flutter/material.dart';

/// Renders directional arrows matching the React TurnArrow SVGs.
class TurnArrow extends StatelessWidget {
  final String type;
  final double size;
  final Color color;

  const TurnArrow({
    super.key,
    this.type = 'straight',
    this.size = 36,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ArrowPainter(type: type, color: color),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final String type;
  final Color color;
  _ArrowPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final s = size.width;

    switch (type) {
      case 'turn-left':
        final p = Path()
          ..moveTo(s * .6, s * .85)
          ..lineTo(s * .6, s * .42)
          ..lineTo(s * .28, s * .42);
        canvas.drawPath(p, paint);
        // arrowhead
        canvas.drawLine(Offset(s*.28, s*.42), Offset(s*.44, s*.24), paint);
        canvas.drawLine(Offset(s*.28, s*.42), Offset(s*.44, s*.60), paint);
        break;

      case 'turn-right':
        final p = Path()
          ..moveTo(s * .4, s * .85)
          ..lineTo(s * .4, s * .42)
          ..lineTo(s * .72, s * .42);
        canvas.drawPath(p, paint);
        canvas.drawLine(Offset(s*.72, s*.42), Offset(s*.56, s*.24), paint);
        canvas.drawLine(Offset(s*.72, s*.42), Offset(s*.56, s*.60), paint);
        break;

      case 'turn-slight-left':
        final p = Path()
          ..moveTo(s * .6, s * .85)
          ..lineTo(s * .6, s * .52)
          ..quadraticBezierTo(s * .6, s * .28, s * .32, s * .28);
        canvas.drawPath(p, paint);
        canvas.drawLine(Offset(s*.32, s*.28), Offset(s*.46, s*.12), paint);
        canvas.drawLine(Offset(s*.32, s*.28), Offset(s*.18, s*.44), paint);
        break;

      case 'turn-slight-right':
        final p = Path()
          ..moveTo(s * .4, s * .85)
          ..lineTo(s * .4, s * .52)
          ..quadraticBezierTo(s * .4, s * .28, s * .68, s * .28);
        canvas.drawPath(p, paint);
        canvas.drawLine(Offset(s*.68, s*.28), Offset(s*.54, s*.12), paint);
        canvas.drawLine(Offset(s*.68, s*.28), Offset(s*.82, s*.44), paint);
        break;

      case 'uturn':
        final p = Path()
          ..moveTo(s * .35, s * .85)
          ..lineTo(s * .35, s * .42)
          ..quadraticBezierTo(s * .35, s * .14, s * .65, s * .14)
          ..quadraticBezierTo(s * .88, s * .14, s * .88, s * .42)
          ..lineTo(s * .88, s * .62);
        canvas.drawPath(p, paint);
        canvas.drawLine(Offset(s*.88, s*.62), Offset(s*.72, s*.46), paint);
        canvas.drawLine(Offset(s*.88, s*.62), Offset(s*1.0, s*.46), paint);
        break;

      case 'arrive':
        paint.style = PaintingStyle.stroke;
        canvas.drawCircle(Offset(s*.5, s*.5), s*.3, paint);
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(Offset(s*.5, s*.5), s*.12, paint);
        break;

      default: // straight
        canvas.drawLine(Offset(s*.5, s*.88), Offset(s*.5, s*.12), paint);
        canvas.drawLine(Offset(s*.5, s*.12), Offset(s*.3, s*.36), paint);
        canvas.drawLine(Offset(s*.5, s*.12), Offset(s*.7, s*.36), paint);
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.type != type || old.color != color;
}