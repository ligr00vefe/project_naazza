import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_design.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/word_wrap_text.dart';

const welcomeMessages = [
  '오늘도 건강한 하루 보내세요.',
  '식사 거르지 마세요.',
  '천천히 꼭꼭 씹어 드세요.',
  '잠깐 쉬며 가볍게 몸을 풀어보세요.',
  '오늘도 나를 돌보는 시간을 가져보세요.',
  '편안한 식사 시간을 가져보세요.',
  '오늘의 작은 변화도 가볍게 남겨보세요.',
  '바쁜 하루에도 잠깐 쉬어가세요.',
];

/// Pick once on entering home; typing/profile refreshes never shuffle the copy.
class WelcomeBanner extends StatefulWidget {
  const WelcomeBanner({super.key, this.displayName});
  final String? displayName;
  @override
  State<WelcomeBanner> createState() => _WelcomeBannerState();
}

class _WelcomeBannerState extends State<WelcomeBanner> {
  static int? _previous;
  late final int _index;
  @override
  void initState() {
    super.initState();
    final previous = _previous;
    _index = previous == null
        ? Random().nextInt(welcomeMessages.length)
        : (previous + 1 + Random().nextInt(welcomeMessages.length - 1)) %
              welcomeMessages.length;
    _previous = _index;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.displayName?.trim() ?? '';
    return AppCard(
      key: const ValueKey('home-welcome-banner'),
      color: AppColors.mintSurface,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Image.asset(
            'assets/images/welcome_notebook.png',
            width: 64,
            height: 72,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? '오늘도 반가워요!' : '$name님 환영합니다.',
                  key: const ValueKey('home-welcome-title'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppDesign.sectionTitle,
                ),
                const SizedBox(height: 6),
                WordWrapText(
                  welcomeMessages[_index],
                  key: const ValueKey('home-welcome-message'),
                  style: AppDesign.body.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
