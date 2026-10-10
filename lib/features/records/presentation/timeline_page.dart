import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../domain/health_record.dart';
import '../domain/bowel_form.dart';
import 'meal_photo.dart';
import 'records_controller.dart';
import '../domain/meal_group.dart';
import '../../../core/widgets/main_navigation_bar.dart';

class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});
  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  HealthRecordType? _filter;
  MealCategory? _mealFilter;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordsProvider);
    final records =
        state.value
            ?.where((record) => _filter == null || record.type == _filter)
            .toList() ??
        [];
    final groups = groupMeals(records)
        .where((group) => _mealFilter == null || group.category == _mealFilter)
        .toList();
    final entries =
        <Object>[
          ...groups,
          ...records.where((record) => record.type != HealthRecordType.meal),
        ]..sort((a, b) {
          final left = _entryTime(a), right = _entryTime(b);
          final date = DateUtils.dateOnly(
            right,
          ).compareTo(DateUtils.dateOnly(left));
          if (date != 0) return date;
          if (a is MealGroup && b is MealGroup) return compareMealGroups(a, b);
          if (a is MealGroup) return -1;
          if (b is MealGroup) return 1;
          return left.compareTo(right);
        });
    return Scaffold(
      appBar: AppBar(title: const Text('타임라인')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('전체'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() {
                    _filter = null;
                    _mealFilter = null;
                  }),
                ),
                const SizedBox(width: 8),
                for (final type in HealthRecordType.values) ...[
                  ChoiceChip(
                    label: Text(_typeLabel(type)),
                    selected: _filter == type,
                    onSelected: (_) => setState(() {
                      _filter = type;
                      _mealFilter = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (_filter == HealthRecordType.meal)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('모든 끼니'),
                    selected: _mealFilter == null,
                    onSelected: (_) => setState(() => _mealFilter = null),
                  ),
                  for (final category in MealCategory.values) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(category.label),
                      selected: _mealFilter == category,
                      onSelected: (_) => setState(() => _mealFilter = category),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.hasError
                ? const Center(child: Text('기록을 불러오지 못했어요.'))
                : entries.isEmpty
                ? const _EmptyRecords()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => entries[index] is MealGroup
                        ? _MealGroupCard(group: entries[index] as MealGroup)
                        : _RecordCard(record: entries[index] as HealthRecord),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const MainNavigationBar(selectedIndex: 1),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/record'),
        icon: const Icon(Icons.add),
        label: const Text('기록하기'),
      ),
    );
  }
}

class _RecordCard extends ConsumerWidget {
  const _RecordCard({required this.record});
  final HealthRecord record;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      leading: _RecordLeading(record: record),
      title: Text(
        record.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${_time(record.recordedAt)}  ${record.type == HealthRecordType.bowel ? "${BowelForm.recordLabel(record.data['bristol_type'])} · ${record.data['amount'] ?? '보통'}" : record.summary}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'edit') {
            context.push(_editPath(record.type), extra: record);
          }
          if (value == 'delete') {
            await ref.read(recordsProvider.notifier).remove(record);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('수정')),
          PopupMenuItem(value: 'delete', child: Text('삭제')),
        ],
      ),
    ),
  );
}

class _RecordLeading extends StatelessWidget {
  const _RecordLeading({required this.record});

  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      backgroundColor: _typeColor(record.type).withValues(alpha: 0.14),
      child: Icon(_typeIcon(record.type), color: _typeColor(record.type)),
    );
    final photoPath = record.type == HealthRecordType.meal
        ? record.data['photo_path']?.toString()
        : null;
    if (photoPath == null || photoPath.isEmpty) return fallback;
    return MealPhotoThumbnail(path: photoPath, fallback: fallback);
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.eco_outlined, size: 56, color: AppColors.leaf),
        SizedBox(height: 12),
        Text('아직 기록이 없어요'),
        Text('첫 기록을 남겨보세요.', style: TextStyle(color: AppColors.muted)),
      ],
    ),
  );
}

String _typeLabel(HealthRecordType type) => switch (type) {
  HealthRecordType.meal => '식사',
  HealthRecordType.condition => '증상',
  HealthRecordType.bowel => '배변',
  HealthRecordType.visit => '진료',
  HealthRecordType.alcohol => '음주',
};
IconData _typeIcon(HealthRecordType type) => switch (type) {
  HealthRecordType.meal => Icons.restaurant,
  HealthRecordType.condition => Icons.health_and_safety,
  HealthRecordType.bowel => Icons.circle,
  HealthRecordType.visit => Icons.medical_services_rounded,
  HealthRecordType.alcohol => Icons.sports_bar,
};
Color _typeColor(HealthRecordType type) => switch (type) {
  HealthRecordType.meal => AppColors.primary,
  HealthRecordType.condition => const Color(0xFF8969D3),
  HealthRecordType.bowel => const Color(0xFFE0A020),
  HealthRecordType.visit => const Color(0xFF4B91D5),
  HealthRecordType.alcohol => Colors.amber,
};
String _editPath(HealthRecordType type) => switch (type) {
  HealthRecordType.meal => '/record/meal',
  HealthRecordType.condition => '/record/condition',
  HealthRecordType.bowel => '/record/bowel',
  HealthRecordType.visit => '/record/visit',
  HealthRecordType.alcohol => '/record/alcohol',
};
String _time(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

DateTime _entryTime(Object entry) => entry is MealGroup
    ? entry.latest
    : (entry as HealthRecord).recordedAt.toLocal();

class _MealGroupCard extends StatelessWidget {
  const _MealGroupCard({required this.group});
  final MealGroup group;
  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey('meal-group-${group.key}'),
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      title: Text(
        '${group.category.label} - ${group.foods}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${group.day.year}.${group.day.month}.${group.day.day} · 총 ${group.calories.round()} kcal',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push('/timeline/meal', extra: group),
    ),
  );
}
