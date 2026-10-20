import '../../../core/widgets/word_wrap_text.dart';
import '../../../core/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/record_datetime_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/health_record.dart';
import '../domain/alcohol_record.dart';
import 'records_controller.dart';

class AlcoholRecordPage extends ConsumerStatefulWidget {
  const AlcoholRecordPage({super.key, this.record, this.initialRecordedAt});
  final HealthRecord? record;
  final DateTime? initialRecordedAt;
  @override
  ConsumerState<AlcoholRecordPage> createState() => _AlcoholRecordPageState();
}

class _DrinkInput {
  _DrinkInput([Map<String, Object?>? data]) {
    drink = drinkTypes.contains(data?['drink_type'])
        ? data!['drink_type'] as String
        : '소주';
    glass = data?['glass_label']?.toString() ?? defaultGlass(drink);
    if (!drinkContainers(drink).contains(glass)) glass = '직접 입력';
    count = TextEditingController(text: data?['servings']?.toString() ?? '1');
    custom = TextEditingController(text: data?['glass_ml']?.toString() ?? '');
  }
  final key = UniqueKey();
  late String drink, glass;
  late final TextEditingController count, custom;
  double get servings => double.tryParse(count.text) ?? 0;
  double get ml => glass == '직접 입력'
      ? double.tryParse(custom.text) ?? 0
      : glassSizes[glass]?.toDouble() ?? 0;
  double get total => servings * ml;
  bool get valid =>
      servings.isFinite &&
      servings > 0 &&
      servings < 100000000 &&
      ml.isFinite &&
      ml > 0 &&
      ml < 100000000 &&
      total.isFinite &&
      total < 10000000000;
  Map<String, Object?> get data => {
    'drink_type': drink,
    'servings': servings,
    'glass_label': glass,
    'glass_ml': ml,
    'total_ml': total,
  };
  void dispose() {
    count.dispose();
    custom.dispose();
  }
}

class _AlcoholRecordPageState extends ConsumerState<AlcoholRecordPage> {
  DateTime _recordedAt = DateTime.now();
  final _inputs = <_DrinkInput>[];
  final _memo = TextEditingController();
  @override
  void initState() {
    super.initState();
    _recordedAt =
        widget.record?.recordedAt.toLocal() ??
        widget.initialRecordedAt ??
        DateTime.now();
    final data = widget.record?.data;
    if (data == null) {
      _inputs.add(_DrinkInput());
    } else {
      _inputs.addAll(alcoholItems(data).map(_DrinkInput.new));
      _memo.text = data['memo']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    for (final input in _inputs) {
      input.dispose();
    }
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_inputs.any((i) => !i.valid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('각 주종의 수량과 용량을 0보다 큰 숫자로 입력해 주세요.')),
      );
      return;
    }
    final items = _inputs.map((i) => i.data).toList();
    final total = _inputs.fold<double>(0, (sum, i) => sum + i.total),
        count = _inputs.fold<double>(0, (sum, i) => sum + i.servings);
    if (total >= 10000000000 || count >= 100000000) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('입력한 수량을 확인해 주세요.')));
      return;
    }
    final title = _inputs.map((i) => i.drink).toSet().join(', ');
    final first = items.first;
    final record = HealthRecord(
      id:
          widget.record?.id ??
          'alcohol-${DateTime.now().microsecondsSinceEpoch}',
      userId: ref.read(authRepositoryProvider).currentUser!.id,
      type: HealthRecordType.alcohol,
      recordedAt: _recordedAt,
      title: title,
      summary: '${items.length}개 항목 · 총 ${drinkNumber(total)} cc',
      data: {
        'drink_type': title,
        'servings': count,
        'glass_label': items.length == 1 ? first['glass_label'] : '혼합',
        'glass_ml': items.length == 1 ? first['glass_ml'] : total / count,
        'total_ml': total,
        'items': items,
        'memo': _memo.text.trim(),
      },
    );
    if (widget.record == null) {
      await ref.read(recordsProvider.notifier).create(record);
    } else {
      await ref.read(recordsProvider.notifier).updateRecord(record);
    }
    if (mounted && !ref.read(recordsProvider).hasError) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/calendar');
      }
    }
  }

  Widget _entry(_DrinkInput input, int index) => Card(
    key: input.key,
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '음주 ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (_inputs.length > 1)
                IconButton(
                  tooltip: '주종 삭제',
                  onPressed: () {
                    setState(() => _inputs.remove(input));
                    input.dispose();
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, box) {
              final drink = DropdownButtonFormField<String>(
                key: ValueKey('drink-$index-${input.drink}'),
                initialValue: input.drink,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '주종',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                ),
                items: [
                  for (final drink in drinkTypes)
                    DropdownMenuItem(value: drink, child: Text(drink)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      input.drink = value;
                      input.glass = defaultGlass(value);
                    });
                  }
                },
              );
              final glass = DropdownButtonFormField<String>(
                key: ValueKey('glass-$index-${input.drink}-${input.glass}'),
                initialValue: input.glass,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '잔/병',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                ),
                items: [
                  for (final glass in drinkContainers(input.drink))
                    DropdownMenuItem(
                      value: glass,
                      child: Text(
                        glass == '직접 입력'
                            ? glass
                            : '$glass (${glassSizes[glass]} cc)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => input.glass = value);
                },
              );
              final count = TextField(
                key: ValueKey('count-$index'),
                controller: input.count,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '마신 수량',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                  suffixText: containerUnit(input.glass),
                  hintText: '예: 1 또는 0.5',
                ),
              );
              if (box.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(13) > 20) {
                return Column(
                  children: [
                    drink,
                    const SizedBox(height: 16),
                    glass,
                    const SizedBox(height: 16),
                    count,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: drink),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: glass),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: count),
                ],
              );
            },
          ),
          if (input.glass == '직접 입력') ...[
            const SizedBox(height: 16),
            TextField(
              key: ValueKey('custom-$index'),
              controller: input.custom,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '1개 용량',
                suffixText: 'cc',
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '${input.glass == '직접 입력' ? '직접 입력' : '${glassSizes[input.glass]} cc × ${input.count.text}'} · 소계 ${drinkNumber(input.total)} cc',
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: Text(widget.record == null ? '음주 기록' : '음주 기록 수정')),
    body: ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(20),
      children: [
        RecordDateTimeField(
          label: '기록 시각',
          value: _recordedAt,
          onChanged: (v) => setState(() => _recordedAt = v),
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < _inputs.length; index++)
          _entry(_inputs[index], index),
        OutlinedButton.icon(
          onPressed: () => setState(() => _inputs.add(_DrinkInput())),
          icon: const Icon(Icons.add),
          label: const Text('주종 추가'),
        ),
        const SizedBox(height: 16),
        const WordWrapText('용량이 다르면 직접 입력해 주세요.'),
        const SizedBox(height: 16),
        Text(
          '총 ${drinkNumber(_inputs.fold<double>(0, (sum, i) => sum + i.total))} cc',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _memo,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '메모'),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(20),
      child: FilledButton(
        onPressed: ref.watch(recordsProvider).isLoading ? null : _save,
        child: const Text('기록 저장하기'),
      ),
    ),
  );
}
