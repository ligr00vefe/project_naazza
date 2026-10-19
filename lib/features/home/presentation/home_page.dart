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
    return AppPage(
      title: '홈',
      subtitle: '오늘의 작은 기록을 차곡차곡 쌓아봐요.',
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
          AppCard(
            color: const Color(0xFFF0F5EA),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: WordWrapText(
                        '오늘의 기록',
                        style: AppDesign.sectionTitle,
                      ),
                    ),
                    Text(
                      '${today.month}월 ${today.day}일',
                      style: AppDesign.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _TodayCount('식사', groupMeals(todayRecords).length),
                    _TodayCount(
                      '배변',
                      todayRecords
                          .where(
                            (r) =>
                                r.type == HealthRecordType.bowel &&
                                r.data['had_bowel_movement'] != false,
                          )
                          .length,
                    ),
                    _TodayCount(
                      '컨디션',
                      todayRecords
                          .where((r) => r.type == HealthRecordType.condition)
                          .length,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDesign.sectionGap),
          const AppSectionHeader('빠른 기록'),
          LayoutBuilder(
            builder: (context, box) {
              final single = MediaQuery.textScalerOf(context).scale(13) > 19;
              final width = single ? box.maxWidth : (box.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in [
                    (Icons.restaurant_outlined, '식사 기록', '/record/meal-photo'),
                    (Icons.edit_note_rounded, '배변 기록', '/record/bowel'),
                    (
                      Icons.favorite_border_rounded,
                      '증상 기록',
                      '/record/condition',
                    ),
                    (Icons.event_note_outlined, '내원 기록', '/record/visit'),
                  ])
                    SizedBox(
                      width: width,
                      child: AppCard(
                        padding: EdgeInsets.zero,
                        child: AppListRow(
                          title: item.$2,
                          icon: item.$1,
                          onTap: () => context.push(item.$3),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
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
            for (final record in recentRecords)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDesign.cardGap),
                child: AppRecordTile(
                  title: record is MealGroup
                      ? '${record.category.label} · ${compactMealNames(record)}'
                      : (record as HealthRecord).title,
                  subtitle: record is MealGroup
                      ? '총 ${record.calories.round()} kcal'
                      : (record as HealthRecord).summary,
                  onTap: () => record is MealGroup
                      ? context.push('/timeline/meal', extra: record)
                      : context.push('/records/detail', extra: record),
                ),
              ),
          if (upcomingVisit != null) ...[
            const SizedBox(height: AppDesign.sectionGap),
            const AppSectionHeader('다가오는 진료'),
            _VisitCard(record: upcomingVisit),
          ],
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

class _TodayCount extends StatelessWidget {
  const _TodayCount(this.label, this.count);
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$count', style: AppDesign.metric),
        const SizedBox(height: 4),
        Text(label, style: AppDesign.caption),
      ],
    ),
  );
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.record});
  final HealthRecord record;
  @override
  Widget build(BuildContext context) {
    final next = DateTime.parse(record.data['next_visit_at'].toString());
    return AppRecordTile(
      title: record.title,
      subtitle: '${next.year}.${next.month}.${next.day} · 진료 준비',
      onTap: () => context.push('/visit/preparation', extra: record),
    );
  }
}

DateTime _recentTime(Object record) => record is MealGroup
    ? record.latest
    : (record as HealthRecord).recordedAt.toLocal();
