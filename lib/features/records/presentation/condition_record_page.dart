import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/word_wrap_text.dart';
import '../../../core/widgets/record_datetime_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/health_record.dart';
import 'records_controller.dart';
import 'symptom_event_fields.dart';
import '../../insights/domain/food_observation.dart';

class ConditionRecordPage extends ConsumerStatefulWidget {
  const ConditionRecordPage({super.key, this.record, this.initialRecordedAt});
  final HealthRecord? record;
  final DateTime? initialRecordedAt;
  @override
  ConsumerState<ConditionRecordPage> createState() =>
      _ConditionRecordPageState();
}

class _ConditionRecordPageState extends ConsumerState<ConditionRecordPage> {
  ResponseStatus _status = ResponseStatus.normal;
  DateTime _recordedAt = DateTime.now();
  final _symptoms = <String>{};
  final _events = <String, Map<String, Object?>>{};
  late final String _recordId;
  final _memo = TextEditingController();
  static const options = ['복통', '복부팽만', '피로', '메스꺼움', '설사'];

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _recordId =
        record?.id ?? 'condition-${DateTime.now().microsecondsSinceEpoch}';
    _recordedAt =
        record?.recordedAt.toLocal() ??
        widget.initialRecordedAt ??
        DateTime.now();
    if (record != null) {
      _status = ResponseStatus.values.byName(
        record.data['response_status']?.toString() ?? 'normal',
      );
      _symptoms.addAll(
        List<String>.from(record.data['symptoms'] as List? ?? const []),
      );
      _memo.text = record.data['memo']?.toString() ?? '';
      for (final e in (record.data['symptom_events'] as Map? ?? {}).entries) {
        if (e.key is String && e.value is Map) {
          _events[e.key as String] = Map<String, Object?>.from(e.value as Map);
        }
      }
    }
  }

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_status == ResponseStatus.symptom && _symptoms.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('증상을 하나 이상 선택해 주세요.')));
      return;
    }
    if (_recordedAt.isAfter(DateTime.now()) ||
        _symptoms.any((s) {
          final e = _events[s];
          final start = DateTime.tryParse(e?['started_at']?.toString() ?? '');
          return _status == ResponseStatus.symptom &&
              e?['phase'] == 'new' &&
              (start == null || start.isAfter(_recordedAt));
        })) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('증상 시작 시각은 기록 시각 이전으로 입력해 주세요.')),
      );
      return;
    }
    final user = ref.read(authRepositoryProvider).currentUser!;
    final previousPoints = (ref.read(recordsProvider).value ?? <HealthRecord>[])
        .where(
          (r) =>
              r.id != widget.record?.id && !r.recordedAt.isAfter(_recordedAt),
        )
        .expand(SymptomPoint.read)
        .toList();
    if (_status == ResponseStatus.symptom &&
        _symptoms.any((s) {
          final e = _events[s];
          final episode = e?['episode_id'];
          if (!['ongoing', 'ended'].contains(e?['phase']) || episode == null) {
            return false;
          }
          return !previousPoints.any(
                (p) =>
                    p.symptom == s &&
                    p.phase == 'new' &&
                    p.episode == episode &&
                    !p.at.isAfter(_recordedAt),
              ) ||
              previousPoints.any(
                (p) => p.episode == episode && p.phase == 'ended',
              );
        })) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('연결할 이전 증상을 다시 선택해 주세요.')));
      return;
    }
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
      id: _recordId,
      userId: user.id,
      type: HealthRecordType.condition,
      recordedAt: _recordedAt,
      title: title,
      summary: summary,
      data: {
        'response_status': _status.name,
        'symptoms': _status == ResponseStatus.symptom
            ? _symptoms.toList()
            : <String>[],
        'memo': _memo.text.trim(),
        'symptom_events': {
          if (_status == ResponseStatus.symptom)
            for (final s in _symptoms)
              s: {
                ...?_events[s],
                'phase': _events[s]?['phase'] ?? 'unknown',
                if (_events[s]?['phase'] == 'new')
                  'episode_id': _events[s]?['episode_id'] ?? '$_recordId-$s',
              },
        },
      },
    );
    widget.record == null
        ? await ref.read(recordsProvider.notifier).create(record)
        : await ref.read(recordsProvider.notifier).updateRecord(record);
    if (mounted && !ref.read(recordsProvider).hasError) context.pop();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: Text(widget.record == null ? '컨디션 기록' : '컨디션 수정')),
    body: ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(20),
      children: [
        WordWrapText(
          DateUtils.isSameDay(_recordedAt, DateTime.now())
              ? '지금 내 상태는 어떤가요?'
              : '그때 내 상태는 어떤가요?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 18),
        RecordDateTimeField(
          label: '기록 시각',
          value: _recordedAt,
          onChanged: (v) => setState(() => _recordedAt = v),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final status in ResponseStatus.values)
              ChoiceChip(
                label: Text(switch (status) {
                  ResponseStatus.normal => '이상 없음',
                  ResponseStatus.symptom => '증상 기록',
                  ResponseStatus.skipped => '건너뛰기',
                }),
                selected: _status == status,
                onSelected: (_) => setState(() => _status = status),
              ),
          ],
        ),
        if (_status == ResponseStatus.symptom) ...[
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 8,
                runSpacing: 10,
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
          for (final symptom in _symptoms) ...[
            const SizedBox(height: 14),
            SymptomEventFields(
              symptom: symptom,
              value: _events[symptom] ?? {},
              at: _recordedAt,
              recordId: widget.record?.id,
              records: ref.watch(recordsProvider).value ?? [],
              onChanged: (v) => setState(() => _events[symptom] = v),
            ),
          ],
        ],
        const SizedBox(height: 14),
        if (ref.watch(recordsProvider).hasError)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('저장하지 못했어요. 연결을 확인하고 다시 시도해 주세요.'),
          ),
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
