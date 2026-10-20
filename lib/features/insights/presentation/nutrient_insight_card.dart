import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_design.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/word_wrap_text.dart';
import '../../auth/data/auth_repository.dart';
import '../../records/domain/health_record.dart';
import '../../records/presentation/records_controller.dart';
import '../domain/nutrient_intake.dart';

class NutrientInsightCard extends ConsumerStatefulWidget {
  const NutrientInsightCard({
    super.key,
    required this.records,
    this.day,
    this.compact = false,
  });
  final List<HealthRecord> records;
  final DateTime? day;
  final bool compact;
  @override
  ConsumerState<NutrientInsightCard> createState() =>
      _NutrientInsightCardState();
}

class _NutrientInsightCardState extends ConsumerState<NutrientInsightCard> {
  bool _monthly = false, _saving = false, _expanded = false;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Future<void> _complete(NutrientDay day, bool value) async {
    if (_saving || day.meals.isEmpty) return;
    setState(() => _saving = true);
    final meals = List<HealthRecord>.of(day.meals)
      ..sort((a, b) => a.id.compareTo(b.id));
    final record = meals.last;
    await ref
        .read(recordsProvider.notifier)
        .updateRecord(
          record.copyWith(
            data: {
              ...record.data,
              'nutrition_day_signature': value ? day.signature : null,
            },
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ref.read(recordsProvider).hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기록 완료 상태를 저장하지 못했어요. 다시 시도해 주세요.')),
      );
    }
  }

  String _value(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  @override
  Widget build(BuildContext context) {
    final user =
        ref.watch(authStateProvider).value ??
        ref.read(authRepositoryProvider).currentUser;
    final date = widget.day ?? DateTime.now();
    final day = NutrientDay.fromRecords(widget.records, date);
    final now = DateTime.now();
    final special =
        user?.nutritionLifeStage != null &&
        user?.nutritionLifeStage != 'general';
    final historicalSpecial =
        special &&
        (date.year != now.year ||
            date.month != now.month ||
            date.day != now.day);
    final targets = historicalSpecial
        ? <IntakeNutrient, double>{}
        : KoreanNutrientReference.targets(user, date);
    final nutrients = widget.compact
        ? IntakeNutrient.values.take(3)
        : _expanded
        ? IntakeNutrient.values
        : IntakeNutrient.values.take(6);
    final completed = <NutrientDay>[];
    if (_monthly) {
      for (
        var i = 1;
        i <= DateTime(_month.year, _month.month + 1, 0).day;
        i++
      ) {
        final d = DateTime(_month.year, _month.month, i);
        if (d.isAfter(DateUtils.dateOnly(now))) break;
        final item = NutrientDay.fromRecords(widget.records, d);
        if (item.complete) completed.add(item);
      }
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: WordWrapText(
                  widget.compact
                      ? (widget.day == null ? '오늘의 영양' : '이날의 영양')
                      : widget.day != null
                      ? '이날의 영양'
                      : '영양 인사이트',
                  style: AppDesign.sectionTitle,
                ),
              ),
              TextButton(
                onPressed: () => context.push(
                  widget.compact
                      ? (widget.day == null ? '/insights' : '/nutrition-day')
                      : '/personal-info',
                  extra: widget.compact ? widget.day : null,
                ),
                child: WordWrapText(
                  widget.compact ? '전체 보기' : '내 기준',
                  style: AppDesign.caption,
                ),
              ),
            ],
          ),
          if (targets.isEmpty) ...[
            WordWrapText(
              historicalSpecial
                  ? '임신·수유 기준은 오늘 기록에만 적용해요.'
                  : '생년월일과 영양 기준을 설정하면 권장량과 비교해요.',
              style: AppDesign.caption,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push('/personal-info'),
                child: const Text('내 정보 설정'),
              ),
            ),
          ] else ...[
            if (!widget.compact && widget.day == null) ...[
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('오늘'),
                    selected: !_monthly,
                    onSelected: (_) => setState(() => _monthly = false),
                  ),
                  ChoiceChip(
                    label: const Text('월별'),
                    selected: _monthly,
                    onSelected: special
                        ? null
                        : (_) => setState(() => _monthly = true),
                  ),
                ],
              ),
              if (special)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: WordWrapText(
                    '임신·수유 기준은 오늘 기록에 적용해요.',
                    style: AppDesign.caption,
                  ),
                ),
            ],
            if (_monthly)
              Row(
                children: [
                  IconButton(
                    tooltip: '영양 이전 달',
                    onPressed: _month.isAfter(DateTime(2025))
                        ? () => setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month - 1,
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${_month.year}년 ${_month.month}월',
                      textAlign: TextAlign.center,
                      style: AppDesign.body,
                    ),
                  ),
                  IconButton(
                    tooltip: '영양 다음 달',
                    onPressed: _month.isBefore(DateTime(now.year, now.month))
                        ? () => setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month + 1,
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            for (final n in nutrients)
              Builder(
                builder: (context) {
                  final target = targets[n];
                  if (target == null) return const SizedBox.shrink();
                  final total = day.totals[n];
                  final eligible = completed
                      .where(
                        (d) =>
                            d.hasAll(n) &&
                            KoreanNutrientReference.targets(user, d.day)[n] !=
                                null,
                      )
                      .toList();
                  final fulfilled = eligible
                      .where(
                        (d) => d.fulfilled(
                          n,
                          KoreanNutrientReference.targets(user, d.day)[n],
                        ),
                      )
                      .length;
                  final ratio = !n.comparable
                      ? null
                      : _monthly
                      ? (eligible.isEmpty ? null : fulfilled / eligible.length)
                      : (total == null ? null : total / target);
                  final status = !n.comparable
                      ? (_monthly
                            ? '비교 제외'
                            : total == null
                            ? '정보 없음'
                            : '섭취량 기록')
                      : _monthly
                      ? (eligible.isEmpty
                            ? '정보 없음'
                            : '$fulfilled / ${eligible.length}일 충족')
                      : day.fulfilled(n, target)
                      ? '충족'
                      : total == null
                      ? '정보 없음'
                      : '${(ratio! * 100).clamp(0, 100).floor()}% 기록';
                  final barColor = [
                    AppColors.secondary,
                    AppColors.primary,
                    const Color(0xFF80DDE9),
                  ][n.index % 3];
                  if (widget.compact &&
                      MediaQuery.textScalerOf(context).scale(13) < 20) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(n.label, style: AppDesign.body),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ratio == null
                                ? Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.outline,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  )
                                : Semantics(
                                    label: '${n.label} $status',
                                    child: LinearProgressIndicator(
                                      value: ratio.clamp(0, 1),
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(8),
                                      color: barColor,
                                      backgroundColor: AppColors.outline,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 91,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                total == null
                                    ? '정보 없음'
                                    : '${_value(total)} / ${_value(target)}${n.unit}',
                                key: ValueKey('nutrient-status-${n.name}'),
                                style: AppDesign.caption.copyWith(
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: WordWrapText(
                                n.label,
                                style: AppDesign.body,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                status,
                                key: ValueKey('nutrient-status-${n.name}'),
                                textAlign: TextAlign.end,
                                style: AppDesign.caption,
                              ),
                            ),
                          ],
                        ),
                        if (ratio != null) ...[
                          const SizedBox(height: 7),
                          Semantics(
                            label: '${n.label} $status',
                            child: LinearProgressIndicator(
                              value: ratio.clamp(0, 1),
                              minHeight: 5,
                              borderRadius: BorderRadius.circular(8),
                              color: barColor,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                        ],
                        if (!widget.compact && !_monthly)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: WordWrapText(
                              total == null
                                  ? '기준 ${_value(target)} ${n == IntakeNutrient.niacin ? 'mg NE' : n.unit} · 성분 정보 없음'
                                  : !n.comparable
                                  ? '${_value(total)} mg 기록 · 기준 ${_value(target)} mg NE. 당량 정보가 없어 충족 비교는 제외해요.'
                                  : '${_value(total)} / ${_value(target)} ${n.unit} · ${KoreanNutrientReference.adequateIntake(user, date, n) ? '충분' : '권장'}섭취량${day.hasAll(n) ? '' : ' · ${day.known[n] ?? 0}/${day.foodCount}개 정보 있음'}',
                              style: AppDesign.caption,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            if (!widget.compact)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('extra-nutrients'),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  label: Text(_expanded ? '추가 영양소 접기' : '추가 영양소 6개 보기'),
                ),
              ),
            if (!_monthly && !widget.compact && day.meals.isNotEmpty)
              CheckboxListTile(
                key: const ValueKey('nutrition-day-complete'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const WordWrapText(
                  '이날 먹은 음식을 모두 기록했어요',
                  style: AppDesign.body,
                ),
                value: day.complete,
                onChanged: _saving ? null : (v) => _complete(day, v ?? false),
              ),
            if (!widget.compact)
              WordWrapText(
                _monthly
                    ? '식사 기록 완료 ${completed.length}일 · 성분별 정보가 있는 날짜만 비교해요.'
                    : day.meals.isEmpty
                    ? '식사를 기록하면 영양 현황을 볼 수 있어요.'
                    : day.complete
                    ? '누락된 성분은 0으로 계산하지 않아요.'
                    : '식사 기록 중 · 기록을 마치면 충족 여부를 확인해요.',
                style: AppDesign.caption,
              ),
            if (!widget.compact) ...[
              const SizedBox(height: 10),
              const WordWrapText(
                '기준: 보건복지부·한국영양학회 KDRIs 2025',
                style: AppDesign.caption,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
