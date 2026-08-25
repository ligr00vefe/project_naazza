import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/presentation/accessibility_settings.dart';

class NaazzaMascot extends ConsumerWidget {
  const NaazzaMascot({
    super.key,
    this.size = 150,
    this.semanticLabel = '건강 기록 도우미 나짜',
  });
  final double size;
  final String semanticLabel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion =
        ref.watch(reduceMotionProvider) ||
        MediaQuery.disableAnimationsOf(context);
    final image = Semantics(
      label: semanticLabel,
      image: true,
      child: Image.asset(
        'assets/images/naazza-mascot-v1.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
    if (reduceMotion) return image;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: image,
    );
  }
}
