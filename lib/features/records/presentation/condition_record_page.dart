import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/health_record.dart';
import 'records_controller.dart';

class ConditionRecordPage extends ConsumerStatefulWidget {
  const ConditionRecordPage({super.key, this.record});
  final HealthRecord? record;
  @override
  ConsumerState<ConditionRecordPage> createState() =>
      _ConditionRecordPageState();
}

class _ConditionRecordPageState extends ConsumerState<ConditionRecordPage> {
  ResponseStatus _status = ResponseStatus.normal;
  final _symptoms = <String>{};
  final _memo = TextEditingController();
  static const options = ['복통', '복부팽만', '피로', '메스꺼움', '설사'];

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    if (record != null) {
      _status = ResponseStatus.values.byName(
        record.data['response_status']?.toString() ?? 'normal',
      );
      _symptoms.addAll(
        List<String>.from(record.data['symptoms'] as List? ?? const []),
      );
      _memo.text = record.data['memo']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(authRepositoryProvider).currentUser!;
    final title = switch (_status) {
      ResponseStatus.normal => '평온해요',
      ResponseStatus.skipped => '건너뛰기',
      ResponseStatus.symptom => '증상 기록',
    };
    final summary = _status == ResponseStatus.symptom && _symptoms.isNotEmpty
        ? _symptoms.join(', ')
        : _status == ResponseStatus.normal
        ? '특별한 증상 없음'
        : '상태 미확인';
    final record = HealthRecord(
      id:
          widget.record?.id ??
          'condition-${DateTime.now().microsecondsSinceEpoch}',
      userId: user.id,
      type: HealthRecordType.condition,
      recordedAt: widget.record?.recordedAt ?? DateTime.now(),
      title: title,
      summary: summary,
      data: {
        'response_status': _status.name,
        'symptoms': _symptoms.toList(),
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
    appBar: AppBar(title: Text(widget.record == null ? '컨디션 기록' : '컨디션 수정')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '지금 내 상태는 어떤가요?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 18),
        SegmentedButton<ResponseStatus>(
          segments: const [
            ButtonSegment(
              value: ResponseStatus.normal,
              icon: Icon(Icons.sentiment_satisfied_rounded),
              label: Text('이상 없음'),
            ),
            ButtonSegment(
              value: ResponseStatus.symptom,
              icon: Icon(Icons.health_and_safety_outlined),
              label: Text('증상 기록'),
            ),
            ButtonSegment(
              value: ResponseStatus.skipped,
              icon: Icon(Icons.more_horiz_rounded),
              label: Text('건너뛰기'),
            ),
          ],
          selected: {_status},
          onSelectionChanged: (value) => setState(() => _status = value.first),
        ),
        if (_status == ResponseStatus.symptom) ...[
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final symptom in options)
                    FilterChip(
                      label: Text(symptom),
                      selected: _symptoms.contains(symptom),
                      onSelected: (selected) => setState(
                        () => selected
                            ? _symptoms.add(symptom)
                            : _symptoms.remove(symptom),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _memo,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '메모 (선택)'),
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
