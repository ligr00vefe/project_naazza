import '../../records/domain/health_record.dart';

class InsightSummary {
  const InsightSummary({
    required this.days,
    required this.totalRecords,
    required this.mealCount,
    required this.conditionCount,
    required this.bowelCount,
    required this.normalDays,
    required this.activeDays,
    required this.dailyActivity,
    required this.topSymptoms,
    required this.mealTypeCounts,
    required this.averageEnergyKcal,
    required this.averageBristol,
    required this.observations,
  });
  final int days,
      totalRecords,
      mealCount,
      conditionCount,
      bowelCount,
      normalDays,
      activeDays;
  final List<int> dailyActivity;
  final Map<String, int> topSymptoms, mealTypeCounts;
  final double? averageEnergyKcal, averageBristol;
  final List<String> observations;
  int get consistencyPercent =>
      days == 0 ? 0 : (activeDays * 100 / days).round();

  static InsightSummary fromRecords(
    List<HealthRecord> records, {
    required int days,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final start = today.subtract(Duration(days: days - 1));
    final filtered = records.where((r) {
      final d = _dateOnly(r.recordedAt);
      return !d.isBefore(start) && !d.isAfter(today);
    }).toList();
    final meals = filtered
        .where((r) => r.type == HealthRecordType.meal)
        .toList();
    final conditions = filtered
        .where((r) => r.type == HealthRecordType.condition)
        .toList();
    final bowels = filtered
        .where((r) => r.type == HealthRecordType.bowel)
        .toList();
    final activeDates = filtered.map((r) => _dateKey(r.recordedAt)).toSet();
    final normalDates = conditions
        .where((r) => r.data['response_status'] == 'normal')
        .map((r) => _dateKey(r.recordedAt))
        .toSet();
    final symptoms = <String, int>{};
    for (final record in conditions) {
      for (final symptom in List<Object?>.from(
        record.data['symptoms'] as List? ?? const [],
      )) {
        final label = symptom.toString();
        symptoms[label] = (symptoms[label] ?? 0) + 1;
      }
    }
    final mealTypes = <String, int>{};
    final calories = <double>[];
    for (final meal in meals) {
      final type = meal.data['meal_type']?.toString() ?? 'meal';
      mealTypes[type] = (mealTypes[type] ?? 0) + 1;
      final kcal = meal.data['energy_kcal'];
      if (kcal is num && kcal > 0) calories.add(kcal.toDouble());
    }
    final bristol = bowels
        .map((r) => r.data['bristol_type'])
        .whereType<num>()
        .map((v) => v.toDouble())
        .toList();
    final activity = List<int>.generate(days, (i) {
      final date = start.add(Duration(days: i));
      return filtered
          .where((r) => _dateKey(r.recordedAt) == _dateKey(date))
          .length;
    });
    final sortedSymptoms = Map.fromEntries(
      symptoms.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
    final observations = <String>[];
    if (activeDates.length >= 3) {
      observations.add(
        '$days일 중 ${activeDates.length}일 기록했어요. 꾸준한 기록이 패턴 확인에 도움이 돼요.',
      );
    }
    if (sortedSymptoms.isNotEmpty) {
      final top = sortedSymptoms.entries.first;
      observations.add('가장 자주 기록한 증상은 ${top.key}이며 ${top.value}회 나타났어요.');
    }
    if (meals.length >= 3) {
      final top = mealTypes.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      observations.add('${_mealTypeLabel(top.key)} 기록이 ${top.value}회로 가장 많아요.');
    }
    if (bristol.length >= 3) {
      final avg = bristol.reduce((a, b) => a + b) / bristol.length;
      observations.add('배변 형태의 평균은 Bristol ${avg.toStringAsFixed(1)}이에요.');
    }
    return InsightSummary(
      days: days,
      totalRecords: filtered.length,
      mealCount: meals.length,
      conditionCount: conditions.length,
      bowelCount: bowels.length,
      normalDays: normalDates.length,
      activeDays: activeDates.length,
      dailyActivity: activity,
      topSymptoms: sortedSymptoms,
      mealTypeCounts: mealTypes,
      averageEnergyKcal: calories.isEmpty
          ? null
          : calories.reduce((a, b) => a + b) / calories.length,
      averageBristol: bristol.isEmpty
          ? null
          : bristol.reduce((a, b) => a + b) / bristol.length,
      observations: observations,
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
String _dateKey(DateTime value) => '${value.year}-${value.month}-${value.day}';
String _mealTypeLabel(String value) => switch (value) {
  'breakfast' => '아침',
  'lunch' => '점심',
  'dinner' => '저녁',
  _ => '기타 식사',
};
