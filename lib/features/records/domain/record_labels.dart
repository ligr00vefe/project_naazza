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
    return '변비 · 배변 못함';
  }
  final parts = <String>[if (record.data['constipation'] == true) '변비'];
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
      _ => (record.data['symptoms'] as List? ?? []).join(' · '),
    };
