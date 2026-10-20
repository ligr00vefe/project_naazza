import 'dart:collection';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/domain/birth_date.dart';
import '../../records/domain/health_record.dart';

enum IntakeNutrient {
  protein('단백질', 'g', 'protein_g', 'proteinG'),
  calcium('칼슘', 'mg', 'calcium_mg', 'calciumMg'),
  iron('철', 'mg', 'iron_mg', 'ironMg'),
  vitaminC('비타민 C', 'mg', 'vitamin_c_mg', 'vitaminC'),
  vitaminD('비타민 D', 'μg', 'vitamin_d_ug', 'vitaminD'),
  fiber('식이섬유', 'g', 'fiber_g', 'fiberG'),
  potassium('칼륨', 'mg', 'potassium_mg', 'potassiumMg'),
  phosphorus('인', 'mg', 'phosphorus_mg', 'phosphorusMg'),
  vitaminA('비타민 A', 'μg RAE', 'vitamin_a_rae', 'vitaminA'),
  thiamin('비타민 B1', 'mg', 'thiamin_mg', 'thiaminMg'),
  riboflavin('비타민 B2', 'mg', 'riboflavin_mg', 'riboflavinMg'),
  niacin('니아신', 'mg', 'niacin_mg', 'niacinMg');

  const IntakeNutrient(this.label, this.unit, this.key, this.publicKey);
  final String label, unit, key, publicKey;
  bool get adequateIntake =>
      this == vitaminD || this == fiber || this == potassium;
  // Public API supplies niacin mass, not niacin equivalents (NE), and no
  // tryptophan. Preserve measured intake without inventing an NE comparison.
  bool get comparable => this != niacin;
}

/// Source: MOHW/KNS, 2025 KDRIs, Korean summary pp. ix, x, xii, xiii, xvi, xvii.
/// RNI, or AI where RNI is not established. No upper-limit classification.
abstract final class KoreanNutrientReference {
  static const sourceUrl =
      'https://www.kns.or.kr/fileroom/fileroom_view.asp?BoardID=Kdr&idx=167';
  static const sourceLabel = '보건복지부·한국영양학회, 2025 한국인 영양소 섭취기준';
  static bool adequateIntake(
    AuthUser? user,
    DateTime day,
    IntakeNutrient nutrient,
  ) {
    if (nutrient.adequateIntake) return true;
    final birth = user?.birthDate;
    if (birth == null || ageOn(birth, day) != 0) return false;
    if ([
      IntakeNutrient.phosphorus,
      IntakeNutrient.vitaminA,
      IntakeNutrient.thiamin,
      IntakeNutrient.riboflavin,
      IntakeNutrient.niacin,
    ].contains(nutrient)) {
      return true;
    }
    final months =
        (day.year - birth.year) * 12 +
        day.month -
        birth.month -
        (day.day < birth.day ? 1 : 0);
    return nutrient == IntakeNutrient.calcium ||
        nutrient == IntakeNutrient.vitaminC ||
        (months < 6 &&
            (nutrient == IntakeNutrient.protein ||
                nutrient == IntakeNutrient.iron));
  }

  static const _maxAge = [2, 5, 8, 11, 14, 18, 29, 49, 64, 74, 200];
  // Columns: protein g, calcium mg, iron mg, vitamin C mg, vitamin D μg, fiber g.
  static const _male = <List<double>>[
    [20, 450, 6, 40, 5, 10],
    [25, 550, 6, 45, 5, 15],
    [35, 700, 7, 50, 5, 20],
    [50, 800, 8, 70, 5, 20],
    [60, 950, 11, 90, 10, 25],
    [65, 800, 11, 100, 10, 25],
    [65, 800, 8, 100, 10, 30],
    [65, 800, 8, 100, 10, 30],
    [60, 800, 8, 100, 10, 30],
    [60, 800, 8, 100, 15, 30],
    [60, 800, 7, 100, 15, 30],
  ];
  static const _female = <List<double>>[
    [20, 450, 6, 40, 5, 10],
    [25, 550, 6, 45, 5, 15],
    [35, 700, 7, 50, 5, 15],
    [45, 800, 8, 70, 5, 20],
    [55, 850, 13, 90, 10, 20],
    [55, 700, 12, 100, 10, 20],
    [55, 650, 12, 100, 10, 20],
    [50, 650, 12, 100, 10, 20],
    [50, 750, 7, 100, 10, 25],
    [50, 750, 6, 100, 15, 25],
    [50, 750, 6, 100, 15, 25],
  ];
  // Same age bands. Columns: potassium mg (AI), phosphorus mg (RNI),
  // vitamin A μg RAE, thiamin mg, riboflavin mg, niacin mg NE (RNI).
  // Official summary pp. xii, xiii, xvi. Niacin is reference-only.
  static const _extraMale = <List<double>>[
    [1500, 450, 250, .4, .5, 5],
    [2300, 600, 300, .5, .6, 6],
    [2600, 600, 450, .7, .9, 8],
    [3100, 1200, 600, .9, 1.1, 11],
    [3500, 1200, 750, 1.1, 1.5, 14],
    [3500, 1100, 850, 1.3, 1.7, 16],
    [3500, 650, 800, 1.2, 1.5, 14],
    [3500, 650, 800, 1.2, 1.5, 14],
    [3500, 650, 750, 1.2, 1.5, 14],
    [3500, 650, 700, 1.1, 1.4, 13],
    [3500, 650, 700, 1.1, 1.4, 12],
  ];
  static const _extraFemale = <List<double>>[
    [1500, 450, 250, .4, .5, 5],
    [2300, 600, 300, .5, .6, 6],
    [2600, 600, 400, .7, .8, 8],
    [3100, 1200, 550, .9, 1, 11],
    [3500, 1100, 650, 1.1, 1.2, 14],
    [3500, 1000, 650, 1.1, 1.2, 13],
    [3500, 650, 650, 1.1, 1.2, 13],
    [3500, 650, 650, 1.1, 1.2, 13],
    [3500, 650, 600, 1.1, 1.2, 13],
    [3500, 650, 600, 1, 1.1, 12],
    [3500, 650, 600, .8, 1, 11],
  ];
  static Map<IntakeNutrient, double> targets(AuthUser? user, DateTime day) {
    final birth = user?.birthDate;
    if (birth == null ||
        birth.isAfter(DateTime(day.year, day.month, day.day))) {
      return {};
    }
    final age = ageOn(birth, day);
    final sex = user?.nutritionSex, stage = user?.nutritionLifeStage;
    if (!['male', 'female'].contains(sex) || stage == null) return {};
    if (stage != 'general' &&
        (sex != 'female' ||
            age < 19 ||
            ![
              'pregnant1',
              'pregnant2',
              'pregnant3',
              'nursing',
            ].contains(stage))) {
      return {};
    }
    List<double> values;
    if (age < 1) {
      final months =
          (day.year - birth.year) * 12 +
          day.month -
          birth.month -
          (day.day < birth.day ? 1 : 0);
      values = months < 6
          ? [10, 200, 0.3, 40, 5, 0, 400, 100, 350, .2, .3, 2]
          : [15, 300, 6, 55, 5, 0, 700, 300, 450, .3, .4, 3];
    } else {
      final index = _maxAge.indexWhere((end) => age <= end);
      if (index < 0) return {};
      values = [
        ...(sex == 'male' ? _male : _female)[index],
        ...(sex == 'male' ? _extraMale : _extraFemale)[index],
      ];
    }
    if (stage != 'general') {
      values[0] += stage == 'pregnant2'
          ? 10
          : stage == 'pregnant3'
          ? 30
          : stage == 'nursing'
          ? 25
          : 0;
      values[2] += stage == 'nursing' ? 0 : 9;
      values[3] += stage == 'nursing' ? 40 : 10;
      values[5] += 5;
      values[6] += stage == 'nursing' ? 400 : 0;
      values[8] += stage == 'nursing' ? 490 : 70;
      values[9] += .4;
      values[10] += stage == 'nursing' ? .5 : .4;
      values[11] += stage == 'nursing' ? 3 : 4;
    }
    return {
      for (final n in IntakeNutrient.values)
        if (values[n.index] > 0) n: values[n.index],
    };
  }
}

double? _number(Object? raw) {
  final value = raw is num
      ? raw.toDouble()
      : double.tryParse(raw?.toString() ?? '');
  return value != null && value.isFinite && value >= 0 ? value : null;
}

class NutrientDay {
  NutrientDay(this.day, this.meals) {
    for (final meal in meals) {
      final items = meal.data['items'];
      if (items is! List || items.isEmpty) {
        foodCount++;
        continue;
      }
      for (final raw in items) {
        foodCount++;
        if (raw is! Map) continue;
        final amount = _number(raw['amount'] ?? raw['amount_g']);
        if (amount == null || amount <= 0) continue;
        final source = raw['nutrition_source'];
        final sourceBasis = source is Map ? source['basis'] : null;
        final sourceFacts = source is Map ? source['nutrition'] : null;
        final facts = raw['nutrition'];
        for (final nutrient in IntakeNutrient.values) {
          double? value;
          final unit =
              raw['amount_unit'] ??
              (facts is Map ? facts['amount_unit'] : null) ??
              (raw['amount_g'] != null &&
                      facts is Map &&
                      facts['base_amount_g'] != null
                  ? 'g'
                  : null);
          if (!['g', 'ml'].contains(unit)) continue;
          if (sourceBasis is Map &&
              sourceFacts is Map &&
              unit == sourceBasis['unit']) {
            final base = _number(sourceBasis['value']);
            final perBase = _number(sourceFacts[nutrient.publicKey]);
            if (base != null && base > 0 && perBase != null) {
              value = perBase * amount / base;
            }
          }
          if (value == null &&
              source is! Map &&
              facts is Map &&
              (unit == facts['amount_unit'] ||
                  (unit == 'g' && facts['base_amount_g'] != null))) {
            final base = _number(
              facts['base_amount'] ?? facts['base_amount_g'],
            );
            final perBase = _number(facts[nutrient.key]);
            if (base != null && base > 0 && perBase != null) {
              value = perBase * amount / base;
            }
          }
          if (value != null && value.isFinite) {
            totals.update(nutrient, (v) => v + value!, ifAbsent: () => value!);
            known.update(nutrient, (v) => v + 1, ifAbsent: () => 1);
          }
        }
      }
    }
  }
  final DateTime day;
  final List<HealthRecord> meals;
  int foodCount = 0;
  final totals = <IntakeNutrient, double>{};
  final known = <IntakeNutrient, int>{};
  bool hasAll(IntakeNutrient n) => foodCount > 0 && known[n] == foodCount;
  bool get complete =>
      meals.isNotEmpty &&
      meals.any((r) => r.data['nutrition_day_signature'] == signature);
  String get signature {
    final sorted = List<HealthRecord>.of(meals)
      ..sort((a, b) => a.id.compareTo(b.id));
    Object? canonical(Object? v) {
      if (v is Map) {
        return SplayTreeMap<String, Object?>.from({
          for (final e in v.entries) e.key.toString(): canonical(e.value),
        });
      }
      if (v is List) return v.map(canonical).toList();
      return v;
    }

    final data = [
      for (final r in sorted)
        {
          'id': r.id,
          'at': r.recordedAt.toUtc().toIso8601String(),
          'title': r.title,
          'items': r.data['items'],
          'amount': r.data['amount_text'],
          'energy': r.data['energy_kcal'],
        },
    ];
    return sha256.convert(utf8.encode(jsonEncode(canonical(data)))).toString();
  }

  bool fulfilled(IntakeNutrient n, double? target) =>
      n.comparable &&
      complete &&
      hasAll(n) &&
      target != null &&
      (totals[n] ?? 0) >= target;
  static NutrientDay fromRecords(
    Iterable<HealthRecord> records,
    DateTime day,
  ) => NutrientDay(
    DateTime(day.year, day.month, day.day),
    records.where((r) {
      final d = r.recordedAt.toLocal();
      return r.type == HealthRecordType.meal &&
          d.year == day.year &&
          d.month == day.month &&
          d.day == day.day;
    }).toList(),
  );
}
