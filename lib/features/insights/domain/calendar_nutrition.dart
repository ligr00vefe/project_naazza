import '../../auth/domain/auth_user.dart';
import '../../records/domain/health_record.dart';
import 'nutrient_intake.dart';

enum NutritionMood { happy, pleased, neutral, low, unknown }

/// A record-progress summary, not a nutritional diagnosis. Unknown nutrients
/// and niacin mass (not NE) never enter the denominator. Each included nutrient
/// must be known for every recorded food, and each ratio is capped at 100%.
class CalendarNutrition {
  const CalendarNutrition({
    required this.hasMeals,
    required this.knownCount,
    required this.targetCount,
    this.ratio,
  });
  final bool hasMeals;
  final int knownCount, targetCount;
  final double? ratio;

  NutritionMood get mood {
    final r = ratio;
    if (r == null) return NutritionMood.unknown;
    if (r + 1e-9 >= .9) return NutritionMood.happy;
    if (r + 1e-9 >= .8) return NutritionMood.pleased;
    if (r + 1e-9 >= .7) return NutritionMood.neutral;
    return NutritionMood.low;
  }

  String get description => ratio == null
      ? '식사 기록 있음, 영양 정보 부족'
      : '기록된 식사 기준, 확인된 $knownCount/$targetCount종 영양소 평균 ${((ratio! * 100) + 1e-7).floor()}%';

  factory CalendarNutrition.fromRecords(
    Iterable<HealthRecord> records,
    AuthUser? user,
    DateTime day, {
    DateTime? today,
  }) {
    final intake = NutrientDay.fromRecords(records, day);
    final now = today ?? DateTime.now();
    final historicalSpecial =
        user?.nutritionLifeStage != null &&
        user?.nutritionLifeStage != 'general' &&
        (day.year != now.year || day.month != now.month || day.day != now.day);
    final targets = historicalSpecial
        ? <IntakeNutrient, double>{}
        : KoreanNutrientReference.targets(user, day);
    final comparable = targets.entries.where((e) => e.key.comparable).toList();
    final known = comparable.where((e) => intake.hasAll(e.key)).toList();
    final total = known.fold<double>(
      0,
      (v, e) => v + (intake.totals[e.key]! / e.value).clamp(0, 1),
    );
    return CalendarNutrition(
      hasMeals: intake.meals.isNotEmpty,
      knownCount: known.length,
      targetCount: comparable.length,
      ratio: known.isEmpty ? null : total / known.length,
    );
  }
}
