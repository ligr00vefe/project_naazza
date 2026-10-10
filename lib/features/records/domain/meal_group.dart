import 'health_record.dart';

enum MealCategory {
  breakfast('breakfast', '아침'),
  lunch('lunch', '점심'),
  dinner('dinner', '저녁'),
  snack('snack', '간식'),
  other('meal', '기타');

  const MealCategory(this.value, this.label);
  final String value, label;
  static MealCategory fromValue(Object? value) =>
      values.where((category) => category.value == value).firstOrNull ?? other;
}

class MealGroup {
  MealGroup({
    required this.day,
    required this.category,
    required this.records,
    this.recordIds,
  });
  final Set<String>? recordIds;
  final DateTime day;
  final MealCategory category;
  final List<HealthRecord> records;
  String get key => '${day.year}-${day.month}-${day.day}-${category.value}';
  DateTime get latest => records
      .map((r) => r.recordedAt.toLocal())
      .reduce((a, b) => a.isAfter(b) ? a : b);
  double get calories => records.fold(0, (sum, r) => sum + mealCalories(r));
  String get foods => records.map((r) => r.title).join(', ');
  bool contains(HealthRecord record) {
    final date = record.recordedAt.toLocal();
    return (recordIds == null || recordIds!.contains(record.id)) &&
        record.type == HealthRecordType.meal &&
        MealCategory.fromValue(record.data['meal_type']) == category &&
        date.year == day.year &&
        date.month == day.month &&
        date.day == day.day;
  }
}

double? nutritionNumber(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
double mealCalories(HealthRecord record) {
  final saved = nutritionNumber(record.data['energy_kcal']);
  if (saved != null && saved.isFinite && saved > 0) return saved;
  final items = (record.data['items'] as List? ?? []).whereType<Map>();
  return items.fold<double>(0, (sum, item) {
    final nutrition = item['nutrition'] as Map? ?? {};
    final base = nutritionNumber(nutrition['base_amount_g']) ?? 0;
    final amount = nutritionNumber(item['amount_g']) ?? 0;
    final energy = nutritionNumber(nutrition['energy_kcal']) ?? 0;
    return sum +
        (base.isFinite &&
                amount.isFinite &&
                base > 0 &&
                amount > 0 &&
                energy.isFinite &&
                energy >= 0
            ? energy * amount / base
            : 0);
  });
}

int compareMealGroups(MealGroup a, MealGroup b) {
  final date = b.day.compareTo(a.day);
  if (date != 0) return date;
  final category = a.category.index.compareTo(b.category.index);
  return category != 0
      ? category
      : a.records.first.recordedAt.compareTo(b.records.first.recordedAt);
}

List<MealGroup> groupMeals(Iterable<HealthRecord> records) {
  final groups = <String, MealGroup>{};
  for (final record in records.where((r) => r.type == HealthRecordType.meal)) {
    final date = record.recordedAt.toLocal();
    final day = DateTime(date.year, date.month, date.day);
    final category = MealCategory.fromValue(record.data['meal_type']);
    final key =
        '${record.userId}-${day.year}-${day.month}-${day.day}-${category.value}';
    (groups.putIfAbsent(
      key,
      () => MealGroup(day: day, category: category, records: []),
    )).records.add(record);
  }
  for (final group in groups.values) {
    group.records.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  }
  return groups.values.toList()..sort(compareMealGroups);
}

/// 같은 끼니를 1시간 안에 연속 등록한 음식만 하나의 시간 묶음으로 표시한다.
List<MealGroup> groupMealSessions(Iterable<HealthRecord> records) {
  final meals = records.where((r) => r.type == HealthRecordType.meal).toList()
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  final result = <MealGroup>[];
  for (final record in meals) {
    final date = record.recordedAt.toLocal();
    final category = MealCategory.fromValue(record.data['meal_type']);
    final last = result.lastOrNull;
    if (last != null &&
        last.category == category &&
        last.day == DateTime(date.year, date.month, date.day) &&
        date.difference(last.records.last.recordedAt.toLocal()) <=
            const Duration(hours: 1)) {
      last.records.add(record);
      last.recordIds!.add(record.id);
    } else {
      result.add(
        MealGroup(
          day: DateTime(date.year, date.month, date.day),
          category: category,
          records: [record],
          recordIds: {record.id},
        ),
      );
    }
  }
  return result;
}

List<String> mealFoodNames(MealGroup group) => [
  for (final record in group.records)
    ...((record.data['items'] as List? ?? []).whereType<Map>().isEmpty
        ? [record.title]
        : (record.data['items'] as List).whereType<Map>().map(
            (item) => item['name']?.toString() ?? '음식',
          )),
];
String compactMealNames(MealGroup group) {
  final names = mealFoodNames(group);
  return names.length > 1
      ? '${names.first} 외 ${names.length - 1}개'
      : names.first;
}
