import '../../../app/theme/app_colors.dart';
import '../../insights/presentation/nutrient_insight_card.dart';
import '../../insights/domain/calendar_nutrition.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/data/auth_repository.dart';
import 'nutrition_mood_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/word_wrap_text.dart';
import '../../../app/theme/app_design.dart';
import '../domain/health_record.dart';
import '../domain/record_draft_date.dart';
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
      _showAlcohol = true,
      _showWater = true;

  Future<void> _filters() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, update) {
        Widget toggle(
          String title,
          bool value,
          ValueChanged<bool> change, {
          String? subtitle,
        }) => CheckboxListTile(
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          value: value,
          onChanged: (v) {
            setState(() => change(v!));
            update(() {});
          },
        );
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * .85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '표시할 기록',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
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
                      toggle('배변 기록 표시하기', _showBowel, (v) => _showBowel = v),
                      toggle(
                        '검진 기록 표시하기',
                        _showVisits,
                        (v) => _showVisits = v,
                        subtitle: '진료·검진·검사·문진·방문 모두 포함',
                      ),
                      toggle(
                        '음주 기록 표시하기',
                        _showAlcohol,
                        (v) => _showAlcohol = v,
                      ),
                      toggle('물 기록 표시하기', _showWater, (v) => _showWater = v),
                      toggle(
                        '컨디션 기록 표시하기',
                        _showCondition,
                        (v) => _showCondition = v,
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.all(20),
                child: FilledButton(
                  key: const ValueKey('calendar-filter-done'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('완료'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordsProvider);
    final records = state.value ?? [];
    final user =
        ref.watch(authStateProvider).value ??
        ref.read(authRepositoryProvider).currentUser;
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
    return AppPage(
      title: '기록 캘린더',
      selectedIndex: 1,
      actions: [
        TextButton(
          onPressed: () => context.go('/timeline'),
          child: const Text('타임라인'),
        ),
      ],
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.hasError
          ? const Center(child: Text('기록을 불러오지 못했어요.'))
          : AppPageList(
              children: [
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: AppDesign.cardPadding,
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
                                style: AppDesign.sectionTitle,
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
                        _monthGrid(records, user),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            Tooltip(
                              message:
                                  '90% 이상: 웃는 표정 · 80~89%: 옅은 미소 · 70~79%: 무표정 · 70% 미만: 아쉬움 · 정보 부족: 물음표. 확인된 성분을 각각 최대 100%로 반영한 평균이며, 정보 없는 성분은 제외해요.',
                              triggerMode: TooltipTriggerMode.tap,
                              child: const _CalendarLegend(
                                '영양 기준',
                                AppColors.secondary,
                                icon: Icons.sentiment_satisfied_alt_outlined,
                              ),
                            ),
                            if (_showBowel)
                              const _CalendarLegend('배변', Color(0xFFD47A24)),
                            if (_showVisits)
                              const _CalendarLegend(
                                '검진·방문',
                                Colors.blue,
                                icon: Icons.local_hospital_outlined,
                              ),
                            if (_showAlcohol)
                              const _CalendarLegend(
                                '음주',
                                Colors.amber,
                                icon: Icons.sports_bar_outlined,
                              ),
                            if (_showCondition)
                              const _CalendarLegend('컨디션', Colors.purple),
                            if (_showWater)
                              const _CalendarLegend(
                                '물',
                                Colors.lightBlue,
                                icon: Icons.water_drop_outlined,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AppSectionHeader('${_selected.month}월 ${_selected.day}일'),
                if (!_selected.isAfter(DateUtils.dateOnly(DateTime.now())))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FilledButton.icon(
                      key: const ValueKey('calendar-add-record'),
                      onPressed: () => context.push(
                        recordDateRoute(
                          '/record',
                          calendarDraftTime(_selected),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('이 날짜에 기록하기'),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: WordWrapText(
                      '오늘과 지난 날짜에 기록을 추가할 수 있어요.',
                      style: AppDesign.caption,
                    ),
                  ),
                if (selected.any((r) => r.type == HealthRecordType.meal))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: WordWrapText(
                      CalendarNutrition.fromRecords(
                        selected,
                        user,
                        _selected,
                      ).description,
                      style: AppDesign.caption,
                    ),
                  ),
                const SizedBox(height: 20),
                NutrientInsightCard(
                  records: records,
                  day: _selected,
                  compact: true,
                ),
                const SizedBox(height: 16),
                _heading('식사 기록'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '총 ${meals.fold<double>(0, (sum, g) => sum + g.calories).round()} kcal',
                  ),
                ),
                if (meals.isEmpty)
                  const WordWrapText(
                    '선택한 끼니의 기록이 없어요.',
                    style: AppDesign.caption,
                  ),
                for (final group in meals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppRecordTile(
                      title:
                          '${group.category.label} · ${compactMealNames(group)}',
                      subtitle:
                          '${recordTime(group.records.first.recordedAt)} · 총 ${group.calories.round()} kcal',
                      onTap: () => context.push('/timeline/meal', extra: group),
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
                if (_showWater) ...[
                  _heading('물 마시기'),
                  ..._recordList(selected, HealthRecordType.water),
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
    padding: const EdgeInsets.only(top: 12),
    child: AppSectionHeader(text),
  );
  List<Widget> _recordList(List<HealthRecord> selected, HealthRecordType type) {
    final records = selected.where((r) => r.type == type).toList();
    if (records.isEmpty) {
      return [
        const Text('기록이 없어요.', style: AppDesign.caption),
        const SizedBox(height: 12),
      ];
    }
    return [
      for (final record in records)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppRecordTile(
            title: switch (type) {
              HealthRecordType.bowel => compactBowel(record),
              HealthRecordType.condition => compactCondition(record),
              HealthRecordType.alcohol => record.title,
              HealthRecordType.water => '${record.data['cups']}컵',
              _ =>
                record.data['facility_label']?.toString().isNotEmpty == true
                    ? record.data['facility_label'].toString()
                    : '기관 미기록',
            },
            subtitle: type == HealthRecordType.water
                ? '하루 마신 물'
                : type == HealthRecordType.visit
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

            onTap: () => context.push('/records/detail', extra: record),
          ),
        ),
    ];
  }

  Widget _monthGrid(List<HealthRecord> records, AuthUser? user) {
    final offset = _month.weekday % 7;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final count = ((offset + days) / 7).ceil() * 7;
    final scale = MediaQuery.textScalerOf(context).scale(14);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: scale * 1.35 + 44,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        final day = index - offset + 1;
        if (day < 1 || day > days) return const SizedBox.shrink();
        final date = DateTime(_month.year, _month.month, day);
        final dayRecords = records
            .where((r) => DateUtils.isSameDay(r.recordedAt.toLocal(), date))
            .toList();
        final nutrition = CalendarNutrition.fromRecords(dayRecords, user, date);
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
        final water =
            _showWater &&
            dayRecords.any((r) => r.type == HealthRecordType.water);
        return Semantics(
          label:
              '${date.month}월 $day일${meal ? ', ${nutrition.description}' : ''}${visit ? ', 검진 기록 있음' : ''}${alcohol ? ', 음주 기록 있음' : ''}${bowel ? ', 배변 기록 있음' : ''}${condition ? ', 컨디션 기록 있음' : ''}${water ? ', 물 기록 있음' : ''}',
          selected: active,
          button: true,
          child: InkWell(
            key: ValueKey('calendar-day-${date.year}-${date.month}-$day'),
            onTap: () => setState(() => _selected = date),
            child: Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: active ? AppColors.blueSurface : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    softWrap: false,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 14,
                    child: meal
                        ? NutritionMoodIcon(
                            key: ValueKey('nutrition-mood-$day'),
                            mood: nutrition.mood,
                          )
                        : null,
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (alcohol)
                          Icon(
                            Icons.sports_bar,
                            key: ValueKey('alcohol-marker-$day'),
                            size: 10,
                            color: Colors.amber.shade800,
                          ),
                        if (alcohol && visit) const SizedBox(width: 2),
                        if (visit)
                          Icon(
                            Icons.local_hospital,
                            key: ValueKey('visit-marker-$day'),
                            size: 10,
                            color: Colors.blue,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 7,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (bowel)
                          Icon(
                            Icons.circle,
                            size: 5,
                            key: ValueKey('bowel-marker-$day'),
                            color: const Color(0xFFD47A24),
                          ),
                        if (bowel && condition) const SizedBox(width: 3),
                        if (condition)
                          Icon(
                            Icons.circle,
                            size: 5,
                            key: ValueKey('condition-marker-$day'),
                            color: Colors.purple,
                          ),
                        if (water && (bowel || condition))
                          const SizedBox(width: 3),
                        if (water)
                          Icon(
                            Icons.water_drop,
                            key: ValueKey('water-marker-$day'),
                            size: 9,
                            color: Colors.lightBlue,
                          ),
                      ],
                    ),
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

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend(this.label, this.color, {this.icon});
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null)
        Icon(icon, size: 13, color: color)
      else
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      const SizedBox(width: 4),
      Text(label, style: AppDesign.caption.copyWith(fontSize: 11)),
    ],
  );
}
