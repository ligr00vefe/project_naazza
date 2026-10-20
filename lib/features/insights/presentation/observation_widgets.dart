import '../../../core/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_design.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/word_wrap_text.dart';
import '../../records/domain/health_record.dart';
import '../../records/presentation/records_controller.dart';
import '../domain/food_observation.dart';

const symptomColors = [Color(0xFFA9E5F1), Color(0xFF71B9FB), Color(0xFF3B6FF5)];

class CountBars extends StatelessWidget {
  const CountBars({super.key, required this.values});
  final Map<String, int> values;
  @override
  Widget build(BuildContext context) {
    final max = values.values.fold<int>(1, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final e in values.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WordWrapText('${e.key} · ${e.value}사례', style: AppDesign.body),
                const SizedBox(height: 5),
                Semantics(
                  label: '${e.key} ${e.value}사례',
                  child: LayoutBuilder(
                    builder: (_, c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: c.maxWidth * e.value / max,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class RecordEvidence extends StatelessWidget {
  const RecordEvidence({super.key, required this.record, this.label});
  final HealthRecord record;
  final String? label;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: WordWrapText(label ?? record.title, style: AppDesign.body),
    subtitle: WordWrapText(
      '${observationTime(record.recordedAt)} · ${record.summary}',
      style: AppDesign.caption,
    ),
    trailing: const Icon(Icons.chevron_right, size: 18),
    onTap: () => context.push('/records/detail', extra: record),
  );
}

class ObservationDetailPage extends ConsumerStatefulWidget {
  const ObservationDetailPage({
    super.key,
    required this.title,
    required this.cases,
    this.onSettings,
    this.watch,
    this.alcohol = false,
    this.start,
    this.end,
  });
  final String title;
  final List<ObservationCase> cases;
  final VoidCallback? onSettings;
  final FoodWatch? watch;
  final bool alcohol;
  final DateTime? start, end;
  @override
  ConsumerState<ObservationDetailPage> createState() =>
      _ObservationDetailPageState();
}

class _ObservationDetailPageState extends ConsumerState<ObservationDetailPage> {
  String? _symptom;
  @override
  Widget build(BuildContext context) {
    final current = ref.watch(recordsProvider).value;
    final cases = current != null && widget.start != null && widget.end != null
        ? observationCases(
            current,
            watch: widget.watch,
            alcohol: widget.alcohol,
            start: widget.start!,
            end: widget.end!,
          )
        : widget.cases;
    final names =
        cases.expand((c) => c.points.map((p) => p.symptom)).toSet().toList()
          ..sort();
    return AppScaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.onSettings != null)
            IconButton(
              onPressed: widget.onSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('전체'),
                selected: _symptom == null,
                onSelected: (_) => setState(() => _symptom = null),
              ),
              for (final s in names)
                ChoiceChip(
                  label: Text(s),
                  selected: _symptom == s,
                  onSelected: (_) => setState(() => _symptom = s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const WordWrapText(
            '섭취 당일·다음날 · 이어지는 증상은 종료까지',
            style: AppDesign.caption,
          ),
          const SizedBox(height: 12),
          for (final c in cases) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WordWrapText(
                    observationTime(c.at),
                    style: AppDesign.sectionTitle,
                  ),
                  const SizedBox(height: 10),
                  CaseTimeline(observation: c, symptom: _symptom),
                  if (c.before != null)
                    RecordEvidence(
                      record: c.before!.record,
                      label: '섭취 전 마지막 기록 · ${c.before!.label}',
                    ),
                  for (final r in c.sources)
                    RecordEvidence(record: r, label: '섭취 · ${r.title}'),
                  for (final p in c.points.where(
                    (p) => _symptom == null || p.symptom == _symptom,
                  ))
                    RecordEvidence(
                      record: p.record,
                      label:
                          '${p.symptom} · ${p.phaseLabel}${p.severity == null ? '' : ' · ${['', '약함', '보통', '심함'][p.severity!]}'}',
                    ),
                  for (final s in c.states.where((s) => s.symptoms.isEmpty))
                    RecordEvidence(
                      record: s.record,
                      label: '이상 없음 · 기록한 시점의 상태',
                    ),
                  if (c.points.isEmpty && c.states.isNotEmpty)
                    const WordWrapText(
                      '선택한 증상 기록 없음 · 상태 기록이 있다는 뜻이며, 관찰 기간 전체의 무증상을 뜻하지 않아요.',
                      style: AppDesign.caption,
                    ),
                  if (c.unknown)
                    const WordWrapText(
                      '상태 미확인 · 이후 상태 기록이 없어요.',
                      style: AppDesign.caption,
                    ),
                  if (c.context.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const WordWrapText(
                        '같은 기간의 다른 음식·음주',
                        style: AppDesign.body,
                      ),
                      children: [
                        for (final r in c.context) RecordEvidence(record: r),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (cases.isEmpty)
            const WordWrapText('선택한 기간에 해당 섭취 기록이 없어요.', style: AppDesign.body),
          const WordWrapText(
            '시간상 함께 기록된 변화예요. 원인 판정이나 발생 확률이 아니에요. 같은 증상이 여러 음식의 관찰에 함께 표시될 수 있어요.',
            style: AppDesign.caption,
          ),
        ],
      ),
    );
  }
}

class CaseTimeline extends StatelessWidget {
  const CaseTimeline({super.key, required this.observation, this.symptom});
  final ObservationCase observation;
  final String? symptom;
  @override
  Widget build(BuildContext context) {
    final points = observation.points
        .where((p) => symptom == null || p.symptom == symptom)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WordWrapText('● 섭취 → 당일 → 다음날', style: AppDesign.caption),
        const SizedBox(height: 10),
        Semantics(
          label: '섭취와 증상 시점 차트. 아래 목록에서 시각과 상태를 확인할 수 있어요.',
          child: SizedBox(
            height: 54,
            child: CustomPaint(painter: _TimelinePainter(observation, points)),
          ),
        ),
        const SizedBox(height: 6),
        for (final p in points)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  p.phase == 'new'
                      ? Icons.circle
                      : p.phase == 'ended'
                      ? Icons.check_circle_outline
                      : p.phase == 'ongoing'
                      ? Icons.arrow_forward
                      : Icons.help_outline,
                  size: 13,
                  color: p.phase == 'new'
                      ? AppColors.danger
                      : p.phase == 'ongoing'
                      ? Colors.orange.shade700
                      : AppColors.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: WordWrapText(
                    '${observationTime(p.at)} · ${p.symptom} ${p.phaseLabel}',
                    style: AppDesign.caption,
                  ),
                ),
              ],
            ),
          ),
        if (points.isEmpty)
          const WordWrapText('— 선택한 증상 시점 미확인', style: AppDesign.caption),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter(this.observation, this.points);
  final ObservationCase observation;
  final List<SymptomPoint> points;
  @override
  void paint(Canvas canvas, Size size) {
    final times = [observation.at, observation.end, ...points.map((p) => p.at)]
      ..sort();
    final start = times.first.millisecondsSinceEpoch,
        span = (times.last.millisecondsSinceEpoch - start).clamp(1, 1 << 62);
    double x(DateTime t) =>
        8 + (size.width - 16) * (t.millisecondsSinceEpoch - start) / span;
    final line = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 2;
    canvas.drawLine(Offset(8, 27), Offset(size.width - 8, 27), line);
    for (final p in points.where((p) => p.episode != null)) {
      final prior = points
          .where((v) => v.episode == p.episode && v.at.isBefore(p.at))
          .lastOrNull;
      if (prior != null) {
        canvas.drawLine(
          Offset(x(prior.at), 27),
          Offset(x(p.at), 27),
          Paint()
            ..color = Colors.orange.shade600
            ..strokeWidth = 4,
        );
      }
    }
    canvas.drawCircle(
      Offset(x(observation.at), 27),
      7,
      Paint()..color = Colors.blue.shade600,
    );
    for (final p in points) {
      final color = p.phase == 'new'
          ? AppColors.danger
          : p.phase == 'ongoing'
          ? Colors.orange.shade700
          : AppColors.muted;
      canvas.drawCircle(
        Offset(x(p.at), 27),
        5,
        Paint()
          ..color = color
          ..style = p.phase == 'unknown'
              ? PaintingStyle.stroke
              : PaintingStyle.fill
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) => true;
}
