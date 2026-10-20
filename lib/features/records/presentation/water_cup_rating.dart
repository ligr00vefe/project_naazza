import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../domain/water_record.dart';

/// Integer cup selection; the glasses themselves are the tap/drag surface.
class WaterCupRating extends StatelessWidget {
  const WaterCupRating({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final int value;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      void select(double x) {
        final next = x <= 0
            ? 0
            : ((x / box.maxWidth * maxWaterCups).floor() + 1).clamp(
                0,
                maxWaterCups,
              );
        if (next != value) onChanged?.call(next);
      }

      return GestureDetector(
        key: const ValueKey('water-cup-rating'),
        behavior: HitTestBehavior.opaque,
        onTapUp: onChanged == null ? null : (e) => select(e.localPosition.dx),
        onHorizontalDragStart: onChanged == null
            ? null
            : (e) => select(e.localPosition.dx),
        onHorizontalDragUpdate: onChanged == null
            ? null
            : (e) => select(e.localPosition.dx),
        child: Row(
          children: [
            for (var i = 0; i < maxWaterCups; i++)
              Expanded(
                child: Semantics(
                  key: ValueKey('water-cup-${i + 1}'),
                  button: true,
                  enabled: onChanged != null,
                  selected: i < value,
                  label: '${i + 1}컵 선택',
                  value: i < value ? '채워짐' : '비어 있음',
                  onTap: onChanged == null ? null : () => onChanged!(i + 1),
                  child: SizedBox(
                    height: 78,
                    child: Center(
                      child: SizedBox(
                        width: 32,
                        height: 49,
                        child: CustomPaint(
                          painter: WaterGlassPainter(filled: i < value),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class WaterGlassPainter extends CustomPainter {
  const WaterGlassPainter({required this.filled});
  final bool filled;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cup = Path()
      ..moveTo(w * .09, h * .1)
      ..quadraticBezierTo(w * .5, h * .04, w * .91, h * .1)
      ..lineTo(w * .79, h * .9)
      ..quadraticBezierTo(w * .5, h * .99, w * .21, h * .9)
      ..close();
    if (filled) {
      canvas.save();
      canvas.clipPath(cup);
      final water = Path()
        ..moveTo(0, h * .4)
        ..cubicTo(w * .3, h * .34, w * .6, h * .47, w, h * .4)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(
        water,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, h * .38), Offset(0, h), [
            const Color(0xFF9DE3FF),
            const Color(0xFF4BAFE9),
          ]),
      );
      canvas.drawLine(
        Offset(w * .13, h * .4),
        Offset(w * .87, h * .4),
        Paint()
          ..color = const Color(0xFF369BCC)
          ..strokeWidth = 1,
      );
      canvas.restore();
    }
    canvas.drawPath(
      cup,
      Paint()
        ..color = filled ? const Color(0xFF348BC1) : const Color(0xFF9BAFBD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawOval(
      Rect.fromLTRB(w * .09, h * .04, w * .91, h * .16),
      Paint()
        ..color = const Color(0xFF91AFBE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant WaterGlassPainter oldDelegate) =>
      oldDelegate.filled != filled;
}
