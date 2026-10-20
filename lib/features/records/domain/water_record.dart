import 'health_record.dart';

const maxWaterCups = 7;
DateTime waterDay(DateTime time) {
  final d = time.toLocal();
  return DateTime(d.year, d.month, d.day);
}

String waterDateText(DateTime time) {
  final d = waterDay(time);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

int requireWaterCups(Object? value) {
  if (value is! int || value < 0 || value > maxWaterCups) {
    throw const FormatException('물은 0~7컵의 정수로 기록해 주세요.');
  }
  return value;
}

HealthRecord normalizeWaterRecord(HealthRecord r, {String? id}) {
  final cups = requireWaterCups(r.data['cups']);
  return HealthRecord(
    id: id ?? r.id,
    userId: r.userId,
    type: HealthRecordType.water,
    recordedAt: waterDay(r.recordedAt),
    title: '물 마시기',
    summary: '$cups컵',
    data: {'cups': cups},
  );
}
