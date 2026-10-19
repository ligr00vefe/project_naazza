import '../domain/alcohol_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/health_record.dart';
import '../domain/bowel_form.dart';
import '../domain/record_labels.dart';
import 'records_controller.dart';

class RecordDetailPage extends ConsumerWidget {
  const RecordDetailPage({super.key, required this.record});
  final HealthRecord record;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordsProvider);
    final current = state.value?.where((r) => r.id == record.id).firstOrNull;
    final data = current?.data ?? {};
    final date = current?.recordedAt.toLocal();
    final fields = <(String, String)>[
      if (date != null)
        ('기록 시간', '${date.year}.${date.month}.${date.day} ${recordTime(date)}'),
      if (record.type == HealthRecordType.bowel) ...[
        (
          '상태',
          data['had_bowel_movement'] == false
              ? '변비 · 배변 못함'
              : data['constipation'] == true
              ? '배변 · 변비 있음'
              : '배변',
        ),
        if (data['had_bowel_movement'] != false)
          ('형태', BowelForm.recordLabel(data['bristol_type'])),
        ('통증', '${data['pain'] ?? '미기록'}'),
        ('긴급도', '${data['urgency'] ?? '미기록'}'),
        ('양', '${data['amount'] ?? '미기록'}'),
      ],
      if (record.type == HealthRecordType.condition) ...[
        ('상태', current == null ? '' : compactCondition(current)),
      ],
      if (record.type == HealthRecordType.visit) ...[
        ('기관', '${data['facility_label'] ?? ''}'),
        ('진료과', '${data['department'] ?? ''}'),
        ('구분', visitCategory(data['visit_type'])),
        ('검사 및 결과', '${data['tests'] ?? ''}'),
        ('처방 변경', '${data['medication_changes'] ?? ''}'),
        ('다음 진료', '${data['next_visit_at'] ?? ''}'),
        ('다음 진료 질문', (data['questions'] as List? ?? []).join('\n')),
      ],

      if (record.type == HealthRecordType.alcohol) ...[
        for (final item in alcoholItems(data).indexed)
          ('음주 ${item.$1 + 1}', alcoholItemLabel(item.$2)),
        ('총 용량', '${data['total_ml'] ?? ''} cc'),
      ],
      ('메모', '${data['memo'] ?? ''}'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (record.type) {
          HealthRecordType.bowel => '배변 상세',
          HealthRecordType.visit => '검진·방문 상세',
          HealthRecordType.alcohol => '음주 상세',
          _ => '컨디션 상세',
        }),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () => context.push(switch (record.type) {
                HealthRecordType.bowel => '/record/bowel',
                HealthRecordType.visit => '/record/visit',
                HealthRecordType.alcohol => '/record/alcohol',
                _ => '/record/condition',
              }, extra: current),
              child: const Text('수정'),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.hasError
          ? const Center(child: Text('기록을 불러오지 못했어요.'))
          : current == null
          ? const Center(child: Text('삭제된 기록이에요.'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final field in fields.where((f) => f.$2.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              field.$1,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(field.$2),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
