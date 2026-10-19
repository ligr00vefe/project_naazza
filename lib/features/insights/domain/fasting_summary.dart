import '../../records/domain/health_record.dart';

class FastingInterval {
  const FastingInterval(this.previousLast, this.nextFirst);
  final DateTime previousLast, nextFirst;
  double get hours =>
      nextFirst.difference(previousLast).inMilliseconds / 3600000;
}

List<FastingInterval> fastingIntervals(Iterable<HealthRecord> records) {
  final perUser = <String, Map<DateTime, List<DateTime>>>{};
  for (final r in records.where((r) => r.type == HealthRecordType.meal)) {
    final t = r.recordedAt.toLocal();
    final day = DateTime.utc(t.year, t.month, t.day);
    ((perUser.putIfAbsent(
      r.userId,
      () => {},
    )).putIfAbsent(day, () => [])).add(t);
  }
  final result = <FastingInterval>[];
  for (final days in perUser.values) {
    final ordered = days.keys.toList()..sort();
    for (var i = 1; i < ordered.length; i++) {
      if (ordered[i].difference(ordered[i - 1]).inDays != 1) {
        continue;
      }
      final before = days[ordered[i - 1]]!..sort();
      final after = days[ordered[i]]!..sort();
      final interval = FastingInterval(before.last, after.first);
      if (interval.hours > 0) {
        result.add(interval);
      }
    }
  }
  return result..sort((a, b) => a.nextFirst.compareTo(b.nextFirst));
}

class FastingSummary {
  FastingSummary(
    Iterable<HealthRecord> records, {
    required int year,
    int? month,
  }) : intervals = fastingIntervals(records)
           .where(
             (i) =>
                 i.nextFirst.year == year &&
                 (month == null || i.nextFirst.month == month),
           )
           .toList();
  final List<FastingInterval> intervals;
  int get count => intervals.length;
  double? get averageHours => count == 0
      ? null
      : intervals.fold<double>(0, (sum, i) => sum + i.hours) / count;
}

String fastingDuration(double hours) {
  final minutes = (hours * 60).round();
  return '${minutes ~/ 60}시간 ${minutes % 60}분';
}
