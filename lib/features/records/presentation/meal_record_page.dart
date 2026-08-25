import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/health_record.dart';
import 'records_controller.dart';

class MealRecordPage extends ConsumerStatefulWidget {
  const MealRecordPage({super.key, this.record});
  final HealthRecord? record;
  @override
  ConsumerState<MealRecordPage> createState() => _MealRecordPageState();
}

class _MealRecordPageState extends ConsumerState<MealRecordPage> {
  late final TextEditingController _food;
  late final TextEditingController _amount;
  late final TextEditingController _kcal;
  late final TextEditingController _memo;
  String _mealType = 'meal';

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _food = TextEditingController(text: record?.title ?? '');
    _amount = TextEditingController(
      text: record?.data['amount_text']?.toString() ?? '1인분',
    );
    _kcal = TextEditingController(
      text: record?.data['energy_kcal']?.toString() ?? '',
    );
    _memo = TextEditingController(text: record?.data['memo']?.toString() ?? '');
    _mealType = record?.data['meal_type']?.toString() ?? 'meal';
  }

  @override
  void dispose() {
    _food.dispose();
    _amount.dispose();
    _kcal.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_food.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('음식 이름을 입력해 주세요.')));
      return;
    }
    final user = ref.read(authRepositoryProvider).currentUser!;
    final kcal = int.tryParse(_kcal.text) ?? 0;
    final data = <String, Object?>{
      'meal_type': _mealType,
      'amount_text': _amount.text.trim(),
      'energy_kcal': kcal,
      'memo': _memo.text.trim(),
    };
    final record = HealthRecord(
      id: widget.record?.id ?? 'meal-${DateTime.now().microsecondsSinceEpoch}',
      userId: user.id,
      type: HealthRecordType.meal,
      recordedAt: widget.record?.recordedAt ?? DateTime.now(),
      title: _food.text.trim(),
      summary: '${_amount.text.trim()} · $kcal kcal',
      data: data,
    );
    widget.record == null
        ? await ref.read(recordsProvider.notifier).create(record)
        : await ref.read(recordsProvider.notifier).updateRecord(record);
    if (mounted && !ref.read(recordsProvider).hasError) context.pop();
  }

  @override
  Widget build(BuildContext context) => _RecordScaffold(
    title: widget.record == null ? '식사 직접 입력' : '식사 기록 수정',
    description: 'AI 없이 음식명과 섭취량을 직접 기록해요.',
    saving: ref.watch(recordsProvider).isLoading,
    onSave: _save,
    child: Column(
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'breakfast', label: Text('아침')),
            ButtonSegment(value: 'lunch', label: Text('점심')),
            ButtonSegment(value: 'dinner', label: Text('저녁')),
            ButtonSegment(value: 'meal', label: Text('기타')),
          ],
          selected: {_mealType},
          onSelectionChanged: (value) =>
              setState(() => _mealType = value.first),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _food,
          decoration: const InputDecoration(
            labelText: '음식 이름',
            prefixIcon: Icon(Icons.restaurant_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          decoration: const InputDecoration(
            labelText: '섭취량',
            hintText: '예: 1인분, 200g',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _kcal,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '열량 (선택)',
            suffixText: 'kcal',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _memo,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '메모 (선택)'),
        ),
      ],
    ),
  );
}

class _RecordScaffold extends StatelessWidget {
  const _RecordScaffold({
    required this.title,
    required this.description,
    required this.child,
    required this.saving,
    required this.onSave,
  });
  final String title;
  final String description;
  final Widget child;
  final bool saving;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(description, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 22),
        Card(
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(20),
      child: FilledButton(
        onPressed: saving ? null : onSave,
        child: Text(saving ? '저장 중...' : '기록 저장하기'),
      ),
    ),
  );
}
