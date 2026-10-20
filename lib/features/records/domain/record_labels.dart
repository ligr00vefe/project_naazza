import 'health_record.dart';
import 'bowel_form.dart';

String recordTime(DateTime value) {
  final date = value.toLocal();
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String visitCategory(Object? value) => switch (value) {
  'regular' => '정기진료',
  'checkup' => '검진',
  'test' => '검사',
  'consultation' => '문진',
  'visit' => '방문',
  _ => '기타 방문',
};
String compactBowel(HealthRecord record) {
  if (record.data['had_bowel_movement'] == false) {
    return '변비 · 배변 못함${record.data['blood_in_stool'] == true ? ' · 혈변' : ''}';
  }
  final parts = <String>[
    if (record.data['blood_in_stool'] == true) '혈변',
    if (record.data['constipation'] == true) '변비',
  ];
  if (record.data['pain'] != null && record.data['pain'] != '없음') {
    parts.add('복통');
  }
  final form = BowelForm.fromType(record.data['bristol_type']);
  if (form != null && form.type != 3 && form.type != 4) parts.add(form.label);
  if (record.data['urgency'] != null && record.data['urgency'] != '없음') {
    parts.add('긴급도 ${record.data['urgency']}');
  }
  return parts.isEmpty ? (form == null ? '형태 미기록' : '양호') : parts.join(' · ');
}

String compactCondition(HealthRecord record) =>
    switch (record.data['response_status']) {
      'normal' => '이상 없음',
      'skipped' => '상태 미확인',
      _ =>
        (record.data['symptoms'] as List? ?? [])
            .map((s) {
              final event = (record.data['symptom_events'] as Map? ?? {})[s];
              return event is Map && event['phase'] == 'ended' ? '$s 종료' : '$s';
            })
            .join(' · '),
    };

String symptomEventLabel(Map event) {
  final phase = switch (event['phase']) {
    'new' => '새로 시작',
    'ongoing' => '이어지는 중',
    'ended' => '종료',
    _ => '시작 시점 미확인',
  };
  final start = DateTime.tryParse(
    event['started_at']?.toString() ?? '',
  )?.toLocal();
  final severity = switch (event['severity']) {
    1 => '약함',
    2 => '보통',
    3 => '심함',
    _ => null,
  };
  return [
    phase,
    if (start != null)
      '시작 ${start.year}.${start.month}.${start.day} ${recordTime(start)}',
    if (severity != null && event['phase'] != 'ended') severity,
  ].join(' · ');
}
