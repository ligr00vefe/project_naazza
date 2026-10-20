import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_design.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/word_wrap_text.dart';
import '../../records/domain/health_record.dart';
import '../data/food_watch_repository.dart';
import '../domain/food_observation.dart';
import 'food_watch_editor.dart';
import 'observation_widgets.dart';

class ObservationDashboard extends ConsumerStatefulWidget {
  const ObservationDashboard({super.key, required this.records});
  final List<HealthRecord> records;
  @override
  ConsumerState<ObservationDashboard> createState() =>
      _ObservationDashboardState();
}

class _ObservationDashboardState extends ConsumerState<ObservationDashboard> {
  DateTime _period = localDay(DateTime.now());
  bool _year = false;
  String? _selected;
  DateTime get _start => DateTime(_period.year, _year ? 1 : _period.month);
  DateTime get _end => _year
      ? DateTime(_period.year + 1)
      : DateTime(_period.year, _period.month + 1);
  Future<void> _edit(FoodWatch? watch) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FoodWatchEditor(
          watch: watch,
          records: widget.records,
          onSave: (value) async {
            final all = ref.read(foodWatchesProvider).value ?? [];
            await ref.read(foodWatchesProvider.notifier).save([
              ...all.where((w) => w.id != value.id),
              value,
            ]);
            if (mounted) setState(() => _selected = value.id);
          },
          onDelete: () async {
            final all = ref.read(foodWatchesProvider).value ?? [];
            await ref
                .read(foodWatchesProvider.notifier)
                .save(all.where((w) => w.id != watch?.id).toList());
            if (mounted) setState(() => _selected = null);
          },
        ),
      ),
    );
  }

  void _detail(
    String title,
    List<ObservationCase> cases, {
    FoodWatch? watch,
    bool alcohol = false,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ObservationDetailPage(
        title: title,
        cases: cases,
        watch: watch,
        alcohol: alcohol,
        start: _start,
        end: _end,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final records = widget.records
        .where(
          (r) =>
              !r.recordedAt.isBefore(_start) &&
              r.recordedAt.isBefore(_end) &&
              !r.recordedAt.isAfter(now),
        )
        .toList();
    final alcohol = observationCases(
      widget.records,
      alcohol: true,
      start: _start,
      end: _end,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '이전 기간',
              onPressed: () => setState(
                () => _period = _year
                    ? DateTime(_period.year - 1)
                    : DateTime(_period.year, _period.month - 1),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _year
                      ? '${_period.year}년'
                      : '${_period.year}년 ${_period.month}월',
                  style: AppDesign.sectionTitle,
                ),
              ),
            ),
            IconButton(
              tooltip: '다음 기간',
              onPressed:
                  (_year
                      ? _period.year >= now.year
                      : _period.year == now.year && _period.month >= now.month)
                  ? null
                  : () => setState(
                      () => _period = _year
                          ? DateTime(_period.year + 1)
                          : DateTime(_period.year, _period.month + 1),
                    ),
              icon: const Icon(Icons.chevron_right),
            ),
            PopupMenuButton<bool>(
              tooltip: '기간 단위',
              initialValue: _year,
              onSelected: (v) => setState(() {
                _year = v;
                if (_period.year == now.year) {
                  _period = DateTime(now.year, now.month);
                }
              }),
              itemBuilder: (_) => const [
                PopupMenuItem(value: false, child: Text('월별')),
                PopupMenuItem(value: true, child: Text('연도별')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_year ? '연도별' : '월별', style: AppDesign.body),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSectionHeader('증상·컨디션 추이'),
              WordWrapText(
                _year ? '월별 최대 기록 강도' : '날짜별 최대 기록 강도 · 좌우로 넘겨봐요',
                style: AppDesign.caption,
              ),
              const SizedBox(height: 8),
              SymptomHeatmap(
                records: records,
                start: _start,
                end: _end,
                yearly: _year,
              ),
              const SizedBox(height: 10),
              const WordWrapText(
                '1 약함 · 2 보통 · 3 심함 · ● 강도 미입력 · 체크: 정상·종료 · — 미확인',
                style: AppDesign.caption,
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        const SizedBox(height: AppDesign.sectionGap),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSectionHeader('음주 전후 컨디션'),
              _CaseSummary(cases: alcohol),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => _detail('음주 전후 변화', alcohol, alcohol: true),
                child: const Text('주종·용량과 상태 기록 보기'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDesign.sectionGap),
        AppCard(
          child: ref
              .watch(foodWatchesProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Column(
                  children: [
                    const Text('관찰 목록을 불러오지 못했어요.'),
                    TextButton(
                      onPressed: () => ref.invalidate(foodWatchesProvider),
                      child: const Text('다시 불러오기'),
                    ),
                  ],
                ),
                data: (watches) {
                  final watch =
                      watches.where((w) => w.id == _selected).firstOrNull ??
                      watches.firstOrNull;
                  final cases = watch == null
                      ? <ObservationCase>[]
                      : observationCases(
                          widget.records,
                          watch: watch,
                          start: _start,
                          end: _end,
                        );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSectionHeader(
                        '내가 관찰하는 음식',
                        action: TextButton.icon(
                          onPressed: () => _edit(null),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('추가'),
                        ),
                      ),
                      if (watches.isEmpty)
                        const WordWrapText(
                          '관찰할 음식을 직접 선택해요.',
                          style: AppDesign.body,
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final w in watches)
                            ChoiceChip(
                              label: Text(w.name),
                              selected: watch?.id == w.id,
                              onSelected: (_) =>
                                  setState(() => _selected = w.id),
                            ),
                        ],
                      ),
                      if (watch != null) ...[
                        const SizedBox(height: 16),
                        AppSectionHeader(
                          '${watch.name} · 섭취 후 변화',
                          action: IconButton(
                            tooltip: '포함할 음식 설정',
                            onPressed: () => _edit(watch),
                            icon: const Icon(Icons.tune, size: 20),
                          ),
                        ),
                        _CaseSummary(cases: cases),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () =>
                              _detail('${watch.name} 관찰', cases, watch: watch),
                          child: const Text('관찰 내역과 원본 보기'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const WordWrapText(
                        '시간상 함께 남긴 변화이며 원인이나 발생 확률을 뜻하지 않아요.',
                        style: AppDesign.caption,
                      ),
                    ],
                  );
                },
              ),
        ),
      ],
    );
  }
}

class _CaseSummary extends StatelessWidget {
  const _CaseSummary({required this.cases});
  final List<ObservationCase> cases;
  @override
  Widget build(BuildContext context) {
    // Deduplicate an episode across overlapping exposure windows. No percentages
    // or healthy denominators are inferred from missing follow-up records.
    final points = <String, SymptomPoint>{};
    for (final c in cases) {
      for (final p in c.newSymptoms) {
        points['${p.episode ?? p.record.id}-${p.symptom}'] = p;
      }
    }
    var sameDay = 0, nextDay = 0;
    for (final p in points.values) {
      final matching = cases.where((c) => c.newSymptoms.contains(p)).toList()
        ..sort((a, b) => a.at.compareTo(b.at));
      if (matching.isNotEmpty &&
          localDay(p.at) == localDay(matching.first.at)) {
        sameDay++;
      } else {
        nextDay++;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cases.isEmpty)
          const WordWrapText('선택한 기간에 섭취 기록이 없어요.', style: AppDesign.body)
        else ...[
          AppSectionHeader(
            '새 증상 시작 시점',
            action: IconButton(
              tooltip: '집계 기준',
              icon: const Icon(Icons.info_outline, size: 18),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                useSafeArea: true,
                showDragHandle: true,
                builder: (_) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: WordWrapText(
                    '같은 증상 묶음의 새 시작은 한 번만 세어요. 여러 섭취 기간에 겹치면 가장 이른 섭취를 기준으로 당일·다음날을 나눠요. 지속 기록은 별도 표시하며 기록이 없다고 정상으로 계산하지 않아요. 이 수치는 원인이나 발생 확률이 아니에요.',
                    style: AppDesign.body,
                  ),
                ),
              ),
            ),
          ),
          CountBars(values: {'섭취 당일': sameDay, '다음날': nextDay}),
          const SizedBox(height: 8),
          WordWrapText(
            '지속 기록 ${cases.where((c) => c.hasOngoing).length}사례 · 상태 미확인 ${cases.where((c) => c.unknown).length}사례',
            style: AppDesign.caption,
          ),
          const SizedBox(height: 6),
          WordWrapText(
            '시작 시점 미확인 ${cases.expand((c) => c.points).where((p) => p.phase == 'unknown').map((p) => '${p.record.id}-${p.symptom}').toSet().length}건',
            style: AppDesign.caption,
          ),
        ],
      ],
    );
  }
}

class SymptomHeatmap extends StatefulWidget {
  const SymptomHeatmap({
    super.key,
    required this.records,
    required this.start,
    required this.end,
    required this.yearly,
  });
  final List<HealthRecord> records;
  final DateTime start, end;
  final bool yearly;
  @override
  State<SymptomHeatmap> createState() => _SymptomHeatmapState();
}

class _SymptomHeatmapState extends State<SymptomHeatmap> {
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: _offset(),
  );
  double _offset() {
    if (widget.records.isEmpty) return 0;
    final latest = widget.records
        .map((r) => r.recordedAt.toLocal())
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return ((widget.yearly ? latest.month : latest.day) - 6).clamp(0, 31) *
        34.0;
  }

  @override
  void didUpdateWidget(covariant SymptomHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.start != widget.start || oldWidget.yearly != widget.yearly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(_offset().clamp(0, _scroll.position.maxScrollExtent));
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.start,
        end = widget.end,
        records = widget.records,
        yearly = widget.yearly;
    final today = localDay(DateTime.now());
    final limit = end.isAfter(today) ? today.add(const Duration(days: 1)) : end;
    final periods = yearly
        ? List.generate(
            start.year == today.year ? today.month : 12,
            (i) => DateTime(start.year, i + 1),
          )
        : List.generate(
            limit.difference(start).inDays.clamp(0, 31),
            (i) => DateTime(start.year, start.month, i + 1),
          );
    final points = records.expand(SymptomPoint.read).toList();
    final normal = records
        .where(
          (r) =>
              r.type == HealthRecordType.condition &&
              r.data['response_status'] == 'normal',
        )
        .toList();
    final rowHeight = MediaQuery.textScalerOf(context).scale(14) * 1.5 + 12;
    final headerHeight = MediaQuery.textScalerOf(context).scale(12) * 1.5 + 10;
    Widget cell(Widget child, double height) => SizedBox(
      height: height,
      child: Center(child: child),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cell(const Text('증상', style: AppDesign.caption), headerHeight),
              for (final s in observationSymptoms)
                SizedBox(
                  height: rowHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(s, style: AppDesign.body),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 8),
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(34),
                children: [
                  TableRow(
                    children: [
                      for (final d in periods)
                        cell(
                          Text(
                            '${yearly ? d.month : d.day}${yearly ? '월' : ''}',
                            style: AppDesign.caption,
                          ),
                          headerHeight,
                        ),
                    ],
                  ),
                  for (final s in observationSymptoms)
                    TableRow(
                      children: [
                        for (final d in periods)
                          Builder(
                            builder: (context) {
                              bool inside(DateTime at) {
                                final t = at.toLocal();
                                return t.year == d.year &&
                                    t.month == d.month &&
                                    (yearly || t.day == d.day);
                              }

                              final found = points
                                  .where(
                                    (p) =>
                                        p.symptom == s &&
                                        inside(p.record.recordedAt),
                                  )
                                  .toList();
                              final active = found
                                  .where((p) => p.phase != 'ended')
                                  .toList();
                              final ended = found.any(
                                (p) => p.phase == 'ended',
                              );
                              final normals = normal
                                  .where((r) => inside(r.recordedAt))
                                  .toList();
                              final strength = active.fold<int>(
                                0,
                                (v, p) =>
                                    (p.severity ?? 0) > v ? p.severity! : v,
                              );
                              final label = active.isNotEmpty
                                  ? strength == 0
                                        ? '●'
                                        : '$strength'
                                  : ended
                                  ? '✓'
                                  : normals.isNotEmpty
                                  ? '✓'
                                  : '—';
                              final description = active.isNotEmpty
                                  ? strength == 0
                                        ? '증상 있음 · 강도 미입력'
                                        : '최대 강도 $strength'
                                  : ended
                                  ? '종료 기록'
                                  : normals.isNotEmpty
                                  ? '이상 없음 기록'
                                  : '미확인';
                              final color = active.isNotEmpty
                                  ? symptomColors[(strength == 0
                                            ? 1
                                            : strength) -
                                        1]
                                  : (ended || normals.isNotEmpty)
                                  ? AppColors.lime
                                  : AppColors.background;
                              final evidence =
                                  {
                                    for (final p in found)
                                      p.record.id: p.record,
                                    for (final r in normals) r.id: r,
                                  }.values.toList()..sort(
                                    (a, b) =>
                                        a.recordedAt.compareTo(b.recordedAt),
                                  );
                              return cell(
                                Semantics(
                                  label:
                                      '${d.month}월 ${yearly ? '' : '${d.day}일 '}$s $description',
                                  child: InkWell(
                                    onTap: () => showModalBottomSheet<void>(
                                      context: context,
                                      isScrollControlled: true,
                                      useSafeArea: true,
                                      showDragHandle: true,
                                      builder: (_) => SizedBox(
                                        height:
                                            MediaQuery.sizeOf(context).height *
                                            .6,
                                        child: ListView(
                                          padding: const EdgeInsets.all(20),
                                          children: [
                                            WordWrapText(
                                              '${d.month}월 ${yearly ? '' : '${d.day}일 '}$s',
                                              style: AppDesign.sectionTitle,
                                            ),
                                            for (final r in evidence)
                                              RecordEvidence(record: r),
                                            if (evidence.isEmpty)
                                              const Text('상태 기록이 없어요.'),
                                          ],
                                        ),
                                      ),
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.all(3),
                                      height: rowHeight - 8,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: label == '✓'
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 16,
                                              color: AppColors.primary,
                                            )
                                          : Text(
                                              label,
                                              style: AppDesign.caption,
                                            ),
                                    ),
                                  ),
                                ),
                                rowHeight,
                              );
                            },
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
