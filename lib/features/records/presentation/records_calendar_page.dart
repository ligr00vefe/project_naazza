import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/main_navigation_bar.dart';
import '../domain/health_record.dart';
import '../domain/meal_group.dart';
import '../domain/record_labels.dart';
import 'records_controller.dart';

class RecordsCalendarPage extends ConsumerStatefulWidget {
  const RecordsCalendarPage({super.key});
  @override
  ConsumerState<RecordsCalendarPage> createState() =>
      _RecordsCalendarPageState();
}

class _RecordsCalendarPageState extends ConsumerState<RecordsCalendarPage> {
  DateTime _selected = DateUtils.dateOnly(DateTime.now());
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  MealCategory? _category;
  bool _showVisits = true,
      _showBowel = true,
      _showCondition = true,
      _showAlcohol = true;

  Future<void> _filters() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('표시할 기록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('모든 식사'),
                  selected: _category == null,
                  onSelected: (_) {
                    setState(() => _category = null);
                    update(() {});
                  },
                ),
                for (final category in MealCategory.values)
                  ChoiceChip(
                    label: Text('${category.label}만 보기'),
                    selected: _category == category,
                    onSelected: (_) {
                      setState(() => _category = category);
                      update(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('배변 기록 표시하기'),
              value: _showBowel,
              onChanged: (v) {
                setState(() => _showBowel = v!);
                update(() {});
              },
            ),
            CheckboxListTile(
              title: const Text('검진 기록 표시하기'),
              subtitle: const Text('진료·검진·검사·문진·방문 모두 포함'),
              value: _showVisits,
              onChanged: (v) {
                setState(() => _showVisits = v!);
                update(() {});
              },
            ),
            CheckboxListTile(
              title: const Text('음주 기록 표시하기'),
              value: _showAlcohol,
              onChanged: (v) {
                setState(() => _showAlcohol = v!);
                update(() {});
              },
            ),
            CheckboxListTile(
              title: const Text('컨디션 기록 표시하기'),
              value: _showCondition,
              onChanged: (v) {
                setState(() => _showCondition = v!);
                update(() {});
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('완료'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordsProvider);
    final records = state.value ?? [];
    final selected =
        records
            .where(
              (r) => DateUtils.isSameDay(r.recordedAt.toLocal(), _selected),
            )
            .toList()
          ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    // 먼저 모든 끼니로 시간 묶음을 만든 후 필터링해야, 중간 끼니를 숨겨도 묶음이 합쳐지지 않는다.
    final meals =
        groupMealSessions(
            selected,
          ).where((g) => _category == null || g.category == _category).toList()
          ..sort(compareMealGroups);
    return Scaffold(
      bottomNavigationBar: const MainNavigationBar(selectedIndex: 1),
      appBar: AppBar(
        title: const Text('기록 캘린더'),
        actions: [
          TextButton(
            onPressed: () => context.go('/timeline'),
            child: const Text('타임라인'),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.hasError
          ? const Center(child: Text('기록을 불러오지 못했어요.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: '이전 달',
                              onPressed: () => setState(
                                () => _month = DateTime(
                                  _month.year,
                                  _month.month - 1,
                                ),
                              ),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Text(
                                '${_month.year}년 ${_month.month}월',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              tooltip: '다음 달',
                              onPressed: () => setState(
                                () => _month = DateTime(
                                  _month.year,
                                  _month.month + 1,
                                ),
                              ),
                              icon: const Icon(Icons.chevron_right),
                            ),
                            IconButton(
                              key: const ValueKey('calendar-filter'),
                              tooltip: '기록 필터',
                              onPressed: _filters,
                              icon: const Icon(Icons.filter_list),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            for (final day in [
                              '일',
                              '월',
                              '화',
                              '수',
                              '목',
                              '금',
                              '토',
                            ])
                              Expanded(
                                child: Text(day, textAlign: TextAlign.center),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _monthGrid(records),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            const Text('● 식사'),
                            if (_showBowel) const Text('● 배변'),
                            if (_showVisits)
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_hospital, size: 16),
                                  SizedBox(width: 4),
                                  Text('검진·방문'),
                                ],
                              ),
                            if (_showAlcohol)
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sports_bar, size: 16),
                                  SizedBox(width: 4),
                                  Text('음주'),
                                ],
                              ),
                            if (_showCondition) const Text('● 컨디션'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${_selected.month}월 ${_selected.day}일',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                _heading('식사 기록'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '총 ${meals.fold<double>(0, (sum, g) => sum + g.calories).round()} kcal',
                  ),
                ),
                if (meals.isEmpty) const Text('선택한 끼니의 기록이 없어요.'),
                for (final group in meals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        title: Text(
                          '${group.category.label} · ${compactMealNames(group)}',
                        ),
                        subtitle: Text(
                          '${recordTime(group.records.first.recordedAt)} · 총 ${group.calories.round()} kcal',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push('/timeline/meal', extra: group),
                      ),
                    ),
                  ),
                if (_showBowel) ...[
                  _heading('배변 기록'),
                  ..._recordList(selected, HealthRecordType.bowel),
                ],
                if (_showVisits) ...[
                  _heading('검진 기록'),
                  ..._recordList(selected, HealthRecordType.visit),
                ],
                if (_showAlcohol) ...[
                  _heading('음주 기록'),
                  ..._recordList(selected, HealthRecordType.alcohol),
                ],
                if (_showCondition) ...[
                  _heading('컨디션 기록'),
                  ..._recordList(selected, HealthRecordType.condition),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
  List<Widget> _recordList(List<HealthRecord> selected, HealthRecordType type) {
    final records = selected.where((r) => r.type == type).toList();
    if (records.isEmpty) {
      return [const Text('기록이 없어요.'), const SizedBox(height: 12)];
    }
    return [
      for (final record in records)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: ListTile(
              title: Text(switch (type) {
                HealthRecordType.bowel => compactBowel(record),
                HealthRecordType.condition => compactCondition(record),
                HealthRecordType.alcohol => record.title,
                _ =>
                  record.data['facility_label']?.toString().isNotEmpty == true
                      ? record.data['facility_label'].toString()
                      : '기관 미기록',
              }),
              subtitle: Text(
                type == HealthRecordType.visit
                    ? [
                        recordTime(record.recordedAt),
                        if (record.data['department']?.toString().isNotEmpty ==
                            true)
                          record.data['department'].toString(),
                        visitCategory(record.data['visit_type']),
                      ].join(' · ')
                    : record.type == HealthRecordType.alcohol
                    ? '${recordTime(record.recordedAt)} · ${record.summary}'
                    : recordTime(record.recordedAt),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/records/detail', extra: record),
            ),
          ),
        ),
    ];
  }

  Widget _monthGrid(List<HealthRecord> records) {
    final offset = _month.weekday % 7;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final count = ((offset + days) / 7).ceil() * 7;
    final scale = MediaQuery.textScalerOf(context).scale(14);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: scale * 1.6 + 36,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        final day = index - offset + 1;
        if (day < 1 || day > days) return const SizedBox.shrink();
        final date = DateTime(_month.year, _month.month, day);
        final dayRecords = records.where(
          (r) => DateUtils.isSameDay(r.recordedAt.toLocal(), date),
        );
        final meal = dayRecords.any(
          (r) =>
              r.type == HealthRecordType.meal &&
              (_category == null ||
                  MealCategory.fromValue(r.data['meal_type']) == _category),
        );
        final bowel =
            _showBowel &&
            dayRecords.any((r) => r.type == HealthRecordType.bowel);
        final visit =
            _showVisits &&
            dayRecords.any((r) => r.type == HealthRecordType.visit);
        final condition =
            _showCondition &&
            dayRecords.any((r) => r.type == HealthRecordType.condition);
        final alcohol =
            _showAlcohol &&
            dayRecords.any((r) => r.type == HealthRecordType.alcohol);
        final active = DateUtils.isSameDay(date, _selected);
        return Semantics(
          label: '${date.month}월 $day일${visit ? ', 검진 기록 있음' : ''}',
          selected: active,
          button: true,
          child: InkWell(
            key: ValueKey('calendar-day-${date.year}-${date.month}-$day'),
            onTap: () => setState(() => _selected = date),
            child: Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    softWrap: false,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 2,
                    runSpacing: 2,
                    children: [
                      if (meal)
                        const Icon(Icons.circle, size: 5, color: Colors.green),
                      if (bowel)
                        const Icon(Icons.circle, size: 5, color: Colors.orange),
                      if (condition)
                        const Icon(Icons.circle, size: 5, color: Colors.purple),
                      if (alcohol)
                        Icon(
                          Icons.sports_bar,
                          key: ValueKey('alcohol-marker-$day'),
                          size: 14,
                          color: Colors.amber.shade800,
                        ),
                      if (visit)
                        Icon(
                          Icons.local_hospital,
                          key: ValueKey('visit-marker-$day'),
                          size: 14,
                          color: Colors.blue,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
