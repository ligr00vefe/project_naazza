import '../../../core/widgets/app_page.dart';
import '../../../app/theme/app_design.dart';
import '../../../core/widgets/app_scaffold.dart';
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
        (
          record.type == HealthRecordType.water ? '기록 날짜' : '기록 시간',
          '${date.year}.${date.month}.${date.day}${record.type == HealthRecordType.water ? '' : ' ${recordTime(date)}'}',
        ),
      if (record.type == HealthRecordType.water) ('마신 물', '${data['cups']}컵'),
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
        (
          '혈변',
          switch (data['blood_in_stool']) {
            true => '있음',
            false => '없음',
            _ => '미기록',
          },
        ),
        ('통증', '${data['pain'] ?? '미기록'}'),
        ('긴급도', '${data['urgency'] ?? '미기록'}'),
        ('양', '${data['amount'] ?? '미기록'}'),
      ],
      if (record.type == HealthRecordType.condition) ...[
        ('상태', current == null ? '' : compactCondition(current)),
        for (final e in (data['symptom_events'] as Map? ?? {}).entries)
          if (e.value is Map)
            (e.key.toString(), symptomEventLabel(e.value as Map)),
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
    return AppScaffold(
      appBar: AppBar(
        title: Text(switch (record.type) {
          HealthRecordType.bowel => '배변 상세',
          HealthRecordType.visit => '검진·방문 상세',
          HealthRecordType.alcohol => '음주 상세',
          HealthRecordType.water => '물 마시기 상세',
          _ => '컨디션 상세',
        }),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () => context.push(switch (record.type) {
                HealthRecordType.bowel => '/record/bowel',
                HealthRecordType.visit => '/record/visit',
                HealthRecordType.alcohol => '/record/alcohol',
                HealthRecordType.water => '/record/water',
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
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final field in fields.where((f) => f.$2.isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(field.$1, style: AppDesign.caption),
                              const SizedBox(height: 6),
                              Text(
                                field.$2,
                                style: AppDesign.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
