import 'package:flutter/material.dart';
import '../../../app/theme/app_design.dart';
import '../../../core/widgets/record_datetime_field.dart';
import '../../../core/widgets/word_wrap_text.dart';
import '../../insights/domain/food_observation.dart';
import '../domain/health_record.dart';

class SymptomEventFields extends StatelessWidget {
  const SymptomEventFields({
    super.key,
    required this.symptom,
    required this.value,
    required this.onChanged,
    required this.at,
    required this.records,
    this.recordId,
  });
  final String symptom;
  final Map<String, Object?> value;
  final ValueChanged<Map<String, Object?>> onChanged;
  final DateTime at;
  final List<HealthRecord> records;
  final String? recordId;
  @override
  Widget build(BuildContext context) {
    final phase = value['phase']?.toString() ?? 'unknown';
    final points = records
        .where((r) => r.id != recordId && !r.recordedAt.isAfter(at))
        .expand(SymptomPoint.read)
        .toList();
    final starts =
        points
            .where(
              (p) =>
                  p.symptom == symptom &&
                  p.phase == 'new' &&
                  p.episode != null &&
                  !points.any(
                    (e) => e.episode == p.episode && e.phase == 'ended',
                  ),
            )
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
    final episode = value['episode_id']?.toString();
    final selected = starts.any((p) => p.episode == episode) ? episode : null;
    void update(Map<String, Object?> changes) =>
        onChanged({...value, ...changes});
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WordWrapText(symptom, style: AppDesign.sectionTitle),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: phase,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '증상 상태'),
              items: const [
                DropdownMenuItem(value: 'unknown', child: Text('시작 시점 모름')),
                DropdownMenuItem(value: 'new', child: Text('새로 시작')),
                DropdownMenuItem(value: 'ongoing', child: Text('이어지는 중')),
                DropdownMenuItem(value: 'ended', child: Text('끝났어요')),
              ],
              onChanged: (v) => v == phase
                  ? null
                  : update({
                      'phase': v,
                      'episode_id': null,
                      'started_at': v == 'new'
                          ? at.toUtc().toIso8601String()
                          : null,
                    }),
            ),
            const SizedBox(height: 14),
            if (phase == 'new') ...[
              RecordDateTimeField(
                label: '$symptom 시작 시각',
                value:
                    DateTime.tryParse(
                      value['started_at']?.toString() ?? '',
                    )?.toLocal() ??
                    at,
                onChanged: (v) =>
                    update({'started_at': v.toUtc().toIso8601String()}),
              ),
              const SizedBox(height: 14),
            ],
            if (phase == 'ongoing' || phase == 'ended') ...[
              DropdownButtonFormField<String>(
                key: ValueKey('$symptom-$selected-$phase'),
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '이전에 시작한 같은 증상'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('이전 시작 기록 없음'),
                  ),
                  for (final p in starts)
                    DropdownMenuItem(
                      value: p.episode,
                      child: Text(observationTime(p.at)),
                    ),
                ],
                onChanged: (v) => update({'episode_id': v}),
              ),
              const SizedBox(height: 8),
              const WordWrapText(
                '같은 증상을 연결하면 지속·종료를 함께 볼 수 있어요. 기록 시각이 현재 상태의 시각이에요.',
                style: AppDesign.caption,
              ),
              const SizedBox(height: 14),
            ],
            if (phase != 'ended')
              DropdownButtonFormField<int>(
                initialValue: value['severity'] as int?,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '강도'),
                items: const [
                  DropdownMenuItem<int>(value: null, child: Text('입력 안 함')),
                  DropdownMenuItem(value: 1, child: Text('약함')),
                  DropdownMenuItem(value: 2, child: Text('보통')),
                  DropdownMenuItem(value: 3, child: Text('심함')),
                ],
                onChanged: (v) => update({'severity': v}),
              ),
          ],
        ),
      ),
    );
  }
}
