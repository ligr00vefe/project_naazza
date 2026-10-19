import '../../../core/widgets/record_datetime_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/health_record.dart';
import '../domain/bowel_form.dart';
import 'bowel_form_selector.dart';
import 'records_controller.dart';

class BowelRecordPage extends ConsumerStatefulWidget {
  const BowelRecordPage({super.key, this.record});
  final HealthRecord? record;
  @override
  ConsumerState<BowelRecordPage> createState() => _BowelRecordPageState();
}

class _BowelRecordPageState extends ConsumerState<BowelRecordPage> {
  DateTime _recordedAt = DateTime.now();
  bool _hadMovement = true, _constipation = false;
  int _bristol = 4;
  String _urgency = '없음';
  String _pain = '없음';
  String _amount = '보통';
  final _memo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recordedAt = widget.record?.recordedAt.toLocal() ?? DateTime.now();
    final data = widget.record?.data;
    if (data != null) {
      _hadMovement = data['had_bowel_movement'] != false;
      _constipation = data['constipation'] == true;
      _bristol = data['bristol_type'] as int? ?? 4;
      _urgency = data['urgency']?.toString() ?? '없음';
      _pain = data['pain']?.toString() ?? '없음';
      _amount = data['amount']?.toString() ?? '보통';
      _memo.text = data['memo']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(authRepositoryProvider).currentUser!;
    final record = HealthRecord(
      id: widget.record?.id ?? 'bowel-${DateTime.now().microsecondsSinceEpoch}',
      userId: user.id,
      type: HealthRecordType.bowel,
      recordedAt: _recordedAt,
      title: _hadMovement ? '배변 기록' : '변비 기록',
      summary: _hadMovement
          ? '${_constipation ? '변비 · ' : ''}${BowelForm.recordLabel(_bristol)} · $_amount'
          : '변비 · 배변 못함',
      data: {
        'had_bowel_movement': _hadMovement,
        'constipation': _constipation,
        'bristol_type': _hadMovement ? _bristol : null,
        'urgency': _urgency,
        'pain': _pain,
        'amount': _hadMovement ? _amount : null,
        'memo': _memo.text.trim(),
      },
    );
    widget.record == null
        ? await ref.read(recordsProvider.notifier).create(record)
        : await ref.read(recordsProvider.notifier).updateRecord(record);
    if (mounted && !ref.read(recordsProvider).hasError) context.pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.record == null ? '배변 기록' : '배변 기록 수정')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('오늘의 배변은?', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 18),
        RecordDateTimeField(
          label: '기록 시각',
          value: _recordedAt,
          onChanged: (v) => setState(() => _recordedAt = v),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('배변했어요'),
              selected: _hadMovement,
              onSelected: (_) => setState(() => _hadMovement = true),
            ),
            ChoiceChip(
              label: const Text('변비 · 배변 못함'),
              selected: !_hadMovement,
              onSelected: (_) => setState(() {
                _hadMovement = false;
                _constipation = true;
              }),
            ),
          ],
        ),
        if (_hadMovement)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('변비가 있었어요'),
            value: _constipation,
            onChanged: (v) => setState(() => _constipation = v),
          ),
        const SizedBox(height: 14),
        if (_hadMovement)
          BowelFormSelector(
            value: _bristol,
            onChanged: (value) => setState(() => _bristol = value),
          ),
        const SizedBox(height: 14),
        _ChoiceSection(
          title: '긴급도',
          values: const ['없음', '낮음', '보통', '높음'],
          selected: _urgency,
          onChanged: (value) => setState(() => _urgency = value),
        ),
        const SizedBox(height: 14),
        _ChoiceSection(
          title: '통증 여부',
          values: const ['없음', '약간', '보통', '심함'],
          selected: _pain,
          onChanged: (value) => setState(() => _pain = value),
        ),
        const SizedBox(height: 14),
        if (_hadMovement)
          _ChoiceSection(
            title: '양',
            values: const ['소량', '보통', '많음'],
            selected: _amount,
            onChanged: (value) => setState(() => _amount = value),
          ),
        const SizedBox(height: 14),
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

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.values,
    required this.selected,
    required this.onChanged,
  });
  final String title;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              for (final value in values)
                ChoiceChip(
                  label: Text(value),
                  selected: selected == value,
                  onSelected: (_) => onChanged(value),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
