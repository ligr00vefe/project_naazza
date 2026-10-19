import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/features/insights/domain/fasting_summary.dart';
import 'package:naazza/features/records/domain/health_record.dart';

HealthRecord meal(
  int month,
  int day,
  int hour, {
  String user = 'u',
  String category = 'snack',
}) => HealthRecord(
  id: '$user-$month-$day-$hour',
  userId: user,
  type: HealthRecordType.meal,
  recordedAt: DateTime(2026, month, day, hour),
  title: '음식',
  summary: '',
  data: {'meal_type': category},
);
void main() {
  test('8 consecutive days yield 7 intervals', () {
    final s = FastingSummary(
      [
        for (var d = 1; d <= 8; d++) ...[meal(10, d, 8), meal(10, d, 20)],
      ],
      year: 2026,
      month: 10,
    );
    expect(s.count, 7);
    expect(s.averageHours, 12);
  });
  test('latest and earliest snack used independent of categories', () {
    final s = FastingSummary(
      [
        meal(10, 1, 8, category: 'breakfast'),
        meal(10, 1, 20, category: 'dinner'),
        meal(10, 1, 23),
        meal(10, 2, 7),
        meal(10, 2, 9, category: 'breakfast'),
      ],
      year: 2026,
      month: 10,
    );
    expect(s.count, 1);
    expect(s.averageHours, 8);
  });
  test('missing day and different user never bridged', () {
    expect(fastingIntervals([meal(10, 1, 20), meal(10, 3, 8)]), isEmpty);
    expect(
      fastingIntervals([meal(10, 1, 20), meal(10, 2, 8, user: 'other')]),
      isEmpty,
    );
  });
  test('month boundary belongs to next morning', () {
    final s = FastingSummary(
      [meal(9, 30, 22), meal(10, 1, 8), meal(10, 31, 21), meal(11, 1, 7)],
      year: 2026,
      month: 10,
    );
    expect(s.count, 1);
    expect(s.averageHours, 10);
  });
  test('annual mean weights actual intervals', () {
    final s = FastingSummary([
      meal(1, 1, 22),
      meal(1, 2, 8),
      meal(1, 3, 4),
      meal(2, 1, 22),
      meal(2, 2, 4),
    ], year: 2026);
    expect(s.count, 3);
    expect(s.averageHours, 12);
  });
  test('no data is unknown rather than zero', () {
    expect(FastingSummary([], year: 2026).averageHours, isNull);
  });
}
