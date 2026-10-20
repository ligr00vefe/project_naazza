import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// The same quiet mint curves and blue footer are used by every app flow.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
  });
  final PreferredSizeWidget? appBar;
  final Widget? body, bottomNavigationBar, floatingActionButton;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.background, Color(0xFFFBFEFF)],
      ),
    ),
    child: Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _MintBackdrop())),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: body,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          bottomNavigationBar: bottomNavigationBar == null
              ? null
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .94),
                    border: const Border(
                      top: BorderSide(color: AppColors.outline),
                    ),
                  ),
                  child: bottomNavigationBar,
                ),
          floatingActionButton: floatingActionButton,
        ),
      ],
    ),
  );
}

class _MintBackdrop extends CustomPainter {
  const _MintBackdrop();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .48, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 190)
      ..cubicTo(
        size.width * .83,
        103,
        size.width * .55,
        145,
        size.width * .48,
        0,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = AppColors.mint.withValues(alpha: .10),
    );
  }

  @override
  bool shouldRepaint(_MintBackdrop oldDelegate) => false;
}
