import '../../../core/widgets/app_page.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_design.dart';
import '../domain/record_draft_date.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RecordHubPage extends StatelessWidget {
  const RecordHubPage({super.key, this.initialRecordedAt});
  final DateTime? initialRecordedAt;
  @override
  Widget build(BuildContext context) => AppPage(
    title: '기록하기',
    selectedIndex: 2,
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('어떤 기록을 남길까요?', style: AppDesign.sectionTitle),
        if (initialRecordedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            '${initialRecordedAt!.year}.${initialRecordedAt!.month}.${initialRecordedAt!.day} 기록',
          ),
        ],
        const SizedBox(height: 18),
        _RecordChoice(
          icon: Icons.restaurant_outlined,
          title: '식사 기록',
          subtitle: '사진 분석 또는 직접 입력',
          onTap: () => context.push(
            recordDateRoute('/record/meal-photo', initialRecordedAt),
          ),
        ),
        const SizedBox(height: 12),
        _RecordChoice(
          icon: Icons.sentiment_satisfied_alt_outlined,
          title: '컨디션·증상 기록',
          subtitle: '몸 상태와 증상을 기록해요',
          onTap: () => context.push(
            recordDateRoute('/record/condition', initialRecordedAt),
          ),
        ),
        const SizedBox(height: 12),
        _RecordChoice(
          icon: Icons.spa_outlined,
          title: '배변 기록',
          subtitle: '배변 상태를 기록해요',
          onTap: () =>
              context.push(recordDateRoute('/record/bowel', initialRecordedAt)),
        ),
        const SizedBox(height: 12),
        _RecordChoice(
          icon: Icons.monitor_heart_outlined,
          title: '진료/내원 기록',
          subtitle: '진료 일정과 내원 내역을 기록해요',
          onTap: () =>
              context.push(recordDateRoute('/record/visit', initialRecordedAt)),
        ),
        const SizedBox(height: 12),
        _RecordChoice(
          icon: Icons.sports_bar,
          title: '음주 기록',
          subtitle: '주종·잔 수·용량 기록',
          onTap: () => context.push(
            recordDateRoute('/record/alcohol', initialRecordedAt),
          ),
        ),
        const SizedBox(height: 12),
        _RecordChoice(
          icon: Icons.local_drink_outlined,
          title: '물 마시기',
          subtitle: '하루 마신 물을 컵으로 기록',
          onTap: () =>
              context.push(recordDateRoute('/record/water', initialRecordedAt)),
        ),
      ],
    ),
  );
}

class _RecordChoice extends StatelessWidget {
  const _RecordChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: AppListRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconColor: icon == Icons.sports_bar
          ? AppColors.secondary
          : AppColors.primary,
      onTap: onTap,
    ),
  );
}
