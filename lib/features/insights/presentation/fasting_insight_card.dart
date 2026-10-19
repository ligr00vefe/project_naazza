import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/word_wrap_text.dart';
import '../../../app/theme/app_design.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../records/domain/health_record.dart';
import '../domain/fasting_summary.dart';

class FastingInsightCard extends StatefulWidget {
  const FastingInsightCard({super.key, required this.records});
  final List<HealthRecord> records;
  @override
  State<FastingInsightCard> createState() => _FastingInsightCardState();
}

class _FastingInsightCardState extends State<FastingInsightCard> {
  int _year = DateTime.now().year, _month = DateTime.now().month;
  bool _yearly = false;
  @override
  Widget build(BuildContext context) {
    final years = {
      _year,
      DateTime.now().year,
      ...widget.records
          .where((r) => r.type == HealthRecordType.meal)
          .map((r) => r.recordedAt.toLocal().year),
    }.toList()..sort((a, b) => b.compareTo(a));
    final summary = FastingSummary(
      widget.records,
      year: _year,
      month: _yearly ? null : _month,
    );
    final bars = <({String label, double? hours, int count})>[];
    if (_yearly) {
      for (var month = 1; month <= 12; month++) {
        final part = FastingSummary(widget.records, year: _year, month: month);
        bars.add((
          label: '$month월',
          hours: part.averageHours,
          count: part.count,
        ));
      }
    } else {
      for (final interval in summary.intervals) {
        bars.add((
          label: '${interval.nextFirst.month}/${interval.nextFirst.day}',
          hours: interval.hours,
          count: 1,
        ));
      }
    }
    final maxHours = bars.fold<double>(
      1,
      (value, bar) => math.max(value, bar.hours ?? 0),
    );
    return AppCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: AppDesign.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader('기록 기준 공복 시간'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('월별'),
                  selected: !_yearly,
                  onSelected: (_) => setState(() => _yearly = false),
                ),
                ChoiceChip(
                  label: const Text('연도별'),
                  selected: _yearly,
                  onSelected: (_) => setState(() => _yearly = true),
                ),
                DropdownButton<int>(
                  value: _year,
                  items: [
                    for (final y in years)
                      DropdownMenuItem(value: y, child: Text('$y년')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _year = v);
                    }
                  },
                ),
                if (!_yearly)
                  DropdownButton<int>(
                    value: _month,
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(value: m, child: Text('$m월')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _month = v);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              summary.averageHours == null
                  ? '계산 가능한 기록이 없어요.'
                  : '평균 ${fastingDuration(summary.averageHours!)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('계산한 구간 ${summary.count}회', style: AppDesign.caption),
            const SizedBox(height: 8),
            const WordWrapText(
              '연속된 이틀의 마지막 식사·간식과 다음 날 첫 기록 사이예요. 빠진 날은 제외해요.',
              style: AppDesign.caption,
            ),
            const SizedBox(height: 12),
            if (bars.isNotEmpty) _FastingChart(bars: bars, maxHours: maxHours),
          ],
        ),
      ),
    );
  }
}

class _FastingChart extends StatelessWidget {
  const _FastingChart({required this.bars, required this.maxHours});
  final List<({String label, double? hours, int count})> bars;
  final double maxHours;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 110,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final bar in bars)
              Expanded(
                child: Semantics(
                  label:
                      '${bar.label}, ${bar.hours == null ? '기록 없음' : fastingDuration(bar.hours!)}, ${bar.count}구간',
                  child: Tooltip(
                    triggerMode: TooltipTriggerMode.tap,
                    message:
                        '${bar.label} · ${bar.hours == null ? '기록 없음' : fastingDuration(bar.hours!)} · ${bar.count}구간',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        height: bar.hours == null
                            ? 3
                            : math.max(4, 110 * bar.hours! / maxHours),
                        decoration: BoxDecoration(
                          color: bar.hours == null
                              ? AppColors.outline
                              : AppColors.primary,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: Text(bars.first.label, style: AppDesign.caption)),
          Text(bars.last.label, style: AppDesign.caption),
        ],
      ),
      const SizedBox(height: 6),
      const WordWrapText('막대를 누르면 구간별 시간을 볼 수 있어요.', style: AppDesign.caption),
      if (bars.any((bar) => bar.hours == null))
        const Text('회색: 기록 없음', style: AppDesign.caption),
    ],
  );
}
