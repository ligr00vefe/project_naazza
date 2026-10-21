import '../../../app/theme/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import 'welcome_banner.dart';
import '../../records/presentation/meal_photo.dart';
import '../../insights/presentation/nutrient_insight_card.dart';
import '../../../core/widgets/word_wrap_text.dart';
import '../../records/domain/meal_group.dart';
import '../../records/domain/health_record.dart';
import '../../../core/widgets/app_page.dart';
import '../../../app/theme/app_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../records/presentation/records_controller.dart';
import '../../tracking_profile/domain/tracking_catalog.dart';
import '../../tracking_profile/presentation/tracking_profile_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user =
        ref.watch(authStateProvider).value ??
        ref.read(authRepositoryProvider).currentUser;
    final profile = ref.watch(trackingProfileProvider).value;
    final quickMetrics =
        profile?.metrics.where((item) => item.enabled).take(4) ?? [];
    final allRecords = ref.watch(recordsProvider).value ?? [];
    final recentEntries =
        <Object>[
          ...groupMeals(allRecords),
          ...allRecords.where((record) => record.type != HealthRecordType.meal),
        ]..sort((a, b) {
          final date = DateUtils.dateOnly(
            _recentTime(b),
          ).compareTo(DateUtils.dateOnly(_recentTime(a)));
          if (date != 0) return date;
          if (a is MealGroup && b is MealGroup) return compareMealGroups(a, b);
          if (a is MealGroup) return -1;
          if (b is MealGroup) return 1;
          return _recentTime(a).compareTo(_recentTime(b));
        });
    final recentRecords = recentEntries.take(3).toList();
    final visits =
        ref
            .watch(recordsProvider)
            .value
            ?.where((record) => record.type.name == 'visit')
            .toList() ??
        [];
    final upcomingVisits =
        visits.where((record) {
          final next = DateTime.tryParse(
            record.data['next_visit_at']?.toString() ?? '',
          );
          return next != null && !next.isBefore(DateTime.now());
        }).toList()..sort(
          (a, b) => DateTime.parse(
            a.data['next_visit_at'].toString(),
          ).compareTo(DateTime.parse(b.data['next_visit_at'].toString())),
        );
    final upcomingVisit = upcomingVisits.firstOrNull;
    final today = DateTime.now();
    final todayRecords = allRecords
        .where((r) => DateUtils.isSameDay(r.recordedAt.toLocal(), today))
        .toList();
    final todayWater = todayRecords
        .where((r) => r.type == HealthRecordType.water)
        .firstOrNull;
    return AppPage(
      title: 'NAAZZA',
      selectedIndex: 0,
      actions: [
        IconButton(
          tooltip: '맞춤 추적 설정',
          onPressed: () => context.push('/tracking-profile'),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
      body: AppPageList(
        children: [
          WelcomeBanner(displayName: user?.displayName),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(
              '${today.month}월 ${today.day}일 ${const ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'][today.weekday - 1]}',
              style: AppDesign.sectionTitle,
            ),
          ),
          NutrientInsightCard(records: allRecords, compact: true),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            color: AppColors.blueSurface,
            child: AppListRow(
              title: todayWater == null
                  ? '물 기록하기'
                  : '오늘 마신 물 ${todayWater.data['cups']}컵',
              icon: Icons.local_drink_outlined,
              onTap: () => context.push('/record/water'),
            ),
          ),
          const SizedBox(height: AppDesign.sectionGap),
          const AppSectionHeader('빠른 기록'),
          LayoutBuilder(
            builder: (context, box) {
              final large = MediaQuery.textScalerOf(context).scale(13) > 19;
              final columns = large ? 2 : 3;
              final width = (box.maxWidth - (columns - 1) * 10) / columns;
              const items = [
                (Icons.restaurant_outlined, '식사 기록', '/record/meal-photo'),
                (Icons.spa_outlined, '배변 기록', '/record/bowel'),
                (
                  Icons.sentiment_satisfied_alt_outlined,
                  '증상 기록',
                  '/record/condition',
                ),
                (Icons.monitor_heart_outlined, '내원 기록', '/record/visit'),
                (Icons.sports_bar_outlined, '음주 기록', '/record/alcohol'),
                (Icons.local_drink_outlined, '물 마시기', '/record/water'),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < items.length; i++)
                    SizedBox(
                      width: width,
                      child: AppCard(
                        padding: EdgeInsets.zero,
                        color: i.isEven
                            ? AppColors.mintSurface
                            : AppColors.blueSurface,
                        onTap: () => context.push(items[i].$3),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 16,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                items[i].$1,
                                size: 27,
                                color: i.isEven
                                    ? AppColors.secondary
                                    : AppColors.primary,
                              ),
                              const SizedBox(height: 9),
                              WordWrapText(
                                items[i].$2,
                                style: AppDesign.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          AppSectionHeader(
            '최근 기록',
            action: TextButton(
              onPressed: () => context.push('/timeline'),
              child: const Text('전체 보기', style: AppDesign.caption),
            ),
          ),
          if (recentRecords.isEmpty)
            const AppCard(
              child: WordWrapText('첫 기록을 남겨보세요.', style: AppDesign.caption),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final entry in recentRecords.indexed) ...[
                    if (entry.$1 > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    _RecentRow(record: entry.$2),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '오늘 식사 ${groupMeals(todayRecords).length} · 배변 ${todayRecords.where((r) => r.type == HealthRecordType.bowel && r.data['had_bowel_movement'] != false).length} · 컨디션 ${todayRecords.where((r) => r.type == HealthRecordType.condition).length}',
            style: AppDesign.caption,
          ),
          if (upcomingVisit != null) ...[
            const SizedBox(height: AppDesign.sectionGap),
            const AppSectionHeader('다가오는 진료'),
            _VisitCard(record: upcomingVisit),
          ],
          if (quickMetrics.isNotEmpty) ...[
            const SizedBox(height: AppDesign.sectionGap),
            const AppSectionHeader('나의 추적 항목'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final metric in quickMetrics)
                  Chip(
                    label: Text(TrackingCatalog.metric(metric.metricKey).label),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppDesign.sectionGap),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => context.push('/export'),
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('기록 내보내기', style: AppDesign.caption),
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.record});
  final Object record;
  @override
  Widget build(BuildContext context) {
    final meal = record is MealGroup ? record as MealGroup : null;
    final single = record is HealthRecord ? record as HealthRecord : null;
    final at = _recentTime(record);
    final time =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final path = meal?.records
        .map((r) => r.data['photo_path'])
        .whereType<String>()
        .firstOrNull;
    final icon = switch (single?.type) {
      HealthRecordType.bowel => Icons.spa_outlined,
      HealthRecordType.condition => Icons.sentiment_satisfied_alt_outlined,
      HealthRecordType.visit => Icons.monitor_heart_outlined,
      HealthRecordType.alcohol => Icons.sports_bar_outlined,
      HealthRecordType.water => Icons.local_drink_outlined,
      _ => Icons.restaurant_outlined,
    };
    final badge = AppIconBadge(
      icon,
      color: single?.type == HealthRecordType.condition
          ? const Color(0xFF8969D3)
          : AppColors.secondary,
    );
    return AppListRow(
      title: meal != null
          ? '${meal.category.label} · ${compactMealNames(meal)}'
          : single!.title,
      subtitle: meal != null
          ? '총 ${meal.calories.round()} kcal · $time'
          : '${single!.summary}${single.type == HealthRecordType.water ? '' : ' · $time'}',
      leading: path == null
          ? badge
          : MealPhotoThumbnail(path: path, fallback: badge),
      onTap: () => meal != null
          ? context.push('/timeline/meal', extra: meal)
          : context.push('/records/detail', extra: single),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.record});
  final HealthRecord record;
  @override
  Widget build(BuildContext context) {
    final next = DateTime.parse(record.data['next_visit_at'].toString());
    return AppCard(
      padding: EdgeInsets.zero,
      color: AppColors.mintSurface,
      child: AppListRow(
        title: record.title,
        icon: Icons.monitor_heart_outlined,
        subtitle: '${next.year}.${next.month}.${next.day} · 진료 준비',
        onTap: () => context.push('/visit/preparation', extra: record),
      ),
    );
  }
}

DateTime _recentTime(Object record) => record is MealGroup
    ? record.latest
    : (record as HealthRecord).recordedAt.toLocal();
