import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Code-drawn notebook mark stays crisp without a large illustration asset.
class LoginBrandMark extends StatelessWidget {
  const LoginBrandMark({super.key, required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '새싹 노트',
    image: true,
    child: CustomPaint(size: Size.square(size), painter: _NotebookPainter()),
  );
}

class _NotebookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    canvas.save();
    canvas.translate(49, 48);
    canvas.rotate(-0.12);
    final paper = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-29, -36, 58, 74),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      paper.shift(const Offset(3, 4)),
      Paint()..color = const Color(0xFFE7E7D7),
    );
    canvas.drawRRect(paper, Paint()..color = const Color(0xFFFFF9E8));
    canvas.drawRRect(
      paper,
      Paint()
        ..color = const Color(0xFFA3B6C5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    final binding = Paint()
      ..color = const Color(0xFF55A8DA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var y = -23.0; y < 28; y += 12) {
      canvas.drawArc(
        Rect.fromLTWH(-34, y, 10, 7),
        math.pi * 0.2,
        math.pi * 1.5,
        false,
        binding,
      );
    }
    final stem = Paint()
      ..color = const Color(0xFF14A88C)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(4, 19), const Offset(2, 1), stem);
    canvas.drawPath(
      Path()
        ..moveTo(2, 8)
        ..cubicTo(-15, 7, -18, -8, -14, -9)
        ..cubicTo(-3, -10, 4, -1, 2, 8),
      Paint()..color = const Color(0xFF51CFB2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(2, 5)
        ..cubicTo(1, -10, 13, -17, 18, -15)
        ..cubicTo(18, -4, 12, 4, 2, 5),
      Paint()..color = const Color(0xFF24AD92),
    );
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(82, 86)
        ..quadraticBezierTo(76, 75, 91, 68)
        ..quadraticBezierTo(93, 79, 82, 86),
      Paint()..color = const Color(0xFF41C5AC),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
