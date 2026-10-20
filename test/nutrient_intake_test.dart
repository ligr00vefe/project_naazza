import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/features/auth/domain/auth_user.dart';
import 'package:naazza/features/insights/domain/nutrient_intake.dart';
import 'package:naazza/features/records/domain/health_record.dart';

AuthUser person({
  String sex = 'female',
  String stage = 'general',
  DateTime? birth,
}) => AuthUser(
  id: 'u',
  username: 'tester',
  birthDate: birth ?? DateTime(1976, 10, 20),
  nutritionSex: sex,
  nutritionLifeStage: stage,
);
HealthRecord meal(
  List<Object?> items, {
  String id = 'a',
  DateTime? at,
  Map<String, Object?> extra = const {},
}) => HealthRecord(
  id: id,
  userId: 'u',
  type: HealthRecordType.meal,
  recordedAt: at ?? DateTime(2026, 10, 20, 9),
  title: '같은 상품명',
  summary: '',
  data: {'items': items, ...extra},
);
Map<String, Object?> food({
  double amount = 200,
  String unit = 'ml',
  Object? calcium = 80,
  Object? protein = 5,
}) => {
  'amount': amount,
  'amount_unit': unit,
  'nutrition_source': {
    'basis': {'value': 100, 'unit': 'ml'},
    'nutrition': {'calciumMg': calcium, 'proteinG': protein},
  },
  'nutrition': {'base_amount': 100, 'amount_unit': 'ml'},
};
void main() {
  test(
    'additional 2025 references preserve age, sex, life stage and units',
    () {
      final day = DateTime(2026, 10, 20);
      final male = KoreanNutrientReference.targets(
        person(sex: 'male', birth: DateTime(1990)),
        day,
      );
      expect(male[IntakeNutrient.potassium], 3500);
      expect(male[IntakeNutrient.phosphorus], 650);
      expect(male[IntakeNutrient.vitaminA], 800);
      expect(male[IntakeNutrient.thiamin], 1.2);
      expect(male[IntakeNutrient.riboflavin], 1.5);
      final nursing = KoreanNutrientReference.targets(
        person(stage: 'nursing', birth: DateTime(1990)),
        day,
      );
      expect(nursing[IntakeNutrient.potassium], 3900);
      expect(nursing[IntakeNutrient.vitaminA], 1140);
      expect(nursing[IntakeNutrient.thiamin], closeTo(1.5, .0001));
      final child = KoreanNutrientReference.targets(
        person(birth: DateTime(2018)),
        day,
      );
      expect(child[IntakeNutrient.vitaminA], 400);
      final baby = person(birth: DateTime(2026, 8));
      expect(
        KoreanNutrientReference.adequateIntake(
          baby,
          day,
          IntakeNutrient.thiamin,
        ),
        true,
      );
      expect(
        KoreanNutrientReference.adequateIntake(
          person(),
          day,
          IntakeNutrient.thiamin,
        ),
        false,
      );
    },
  );
  test(
    'additional nutrients scale consumed quantity and niacin never claims NE fulfillment',
    () {
      final item = food(amount: 200);
      (item['nutrition_source'] as Map)['nutrition'] = {
        'potassiumMg': 100,
        'vitaminA': 50,
        'thiaminMg': .2,
        'riboflavinMg': 0,
        'phosphorusMg': null,
        'niacinMg': 99,
      };
      final original = meal([item]);
      final d = NutrientDay.fromRecords([original], original.recordedAt);
      final completed = original.copyWith(
        data: {...original.data, 'nutrition_day_signature': d.signature},
      );
      final recorded = NutrientDay.fromRecords([
        completed,
      ], completed.recordedAt);
      expect(recorded.totals[IntakeNutrient.potassium], 200);
      expect(recorded.totals[IntakeNutrient.vitaminA], 100);
      expect(recorded.totals[IntakeNutrient.thiamin], .4);
      expect(recorded.totals[IntakeNutrient.riboflavin], 0);
      expect(recorded.totals[IntakeNutrient.phosphorus], isNull);
      expect(recorded.fulfilled(IntakeNutrient.niacin, 14), false);
    },
  );
  test(
    'official 2025 age/sex bands switch on birthday; unknown profiles have no invented target',
    () {
      final user = person();
      expect(
        KoreanNutrientReference.targets(
          user,
          DateTime(2026, 10, 19),
        )[IntakeNutrient.calcium],
        650,
      );
      expect(
        KoreanNutrientReference.targets(
          user,
          DateTime(2026, 10, 20),
        )[IntakeNutrient.calcium],
        750,
      );
      expect(
        KoreanNutrientReference.targets(
          user,
          DateTime(2026, 10, 20),
        )[IntakeNutrient.iron],
        7,
      );
      expect(
        KoreanNutrientReference.targets(
          person(sex: 'male', birth: DateTime(1990)),
          DateTime(2026),
        )[IntakeNutrient.protein],
        65,
      );
      expect(
        KoreanNutrientReference.targets(
          const AuthUser(id: 'u', username: 'old'),
          DateTime(2026),
        ),
        isEmpty,
      );
      expect(KoreanNutrientReference.targets(user, DateTime(1975)), isEmpty);
    },
  );
  test(
    'pregnancy trimester and nursing use published additions; child and infant never use adult defaults',
    () {
      for (final stage in ['pregnant1', 'pregnant2', 'pregnant3', 'nursing']) {
        final values = KoreanNutrientReference.targets(
          person(birth: DateTime(1990), stage: stage),
          DateTime(2026),
        );
        expect(
          values[IntakeNutrient.protein],
          {
            'pregnant1': 50,
            'pregnant2': 60,
            'pregnant3': 80,
            'nursing': 75,
          }[stage],
        );
        expect(values[IntakeNutrient.iron], stage == 'nursing' ? 12 : 21);
      }
      final child = KoreanNutrientReference.targets(
        person(birth: DateTime(2024)),
        DateTime(2026),
      );
      expect(child[IntakeNutrient.protein], 20);
      expect(child[IntakeNutrient.calcium], 450);
      final baby = KoreanNutrientReference.targets(
        person(birth: DateTime(2026, 7)),
        DateTime(2026, 10),
      );
      expect(baby[IntakeNutrient.protein], 10);
      expect(baby.containsKey(IntakeNutrient.fiber), false);
    },
  );
  test(
    'portion and product quantity use consumed amount once; missing and zero remain distinct',
    () {
      final day = NutrientDay.fromRecords([
        meal([food(amount: 400), food(calcium: null, protein: 0)]),
      ], DateTime(2026, 10, 20));
      expect(day.totals[IntakeNutrient.calcium], 320);
      expect(day.totals[IntakeNutrient.protein], 20);
      expect(day.known[IntakeNutrient.protein], 2);
      expect(day.known[IntakeNutrient.calcium], 1);
      expect(day.hasAll(IntakeNutrient.calcium), false);
      expect(day.totals.containsKey(IntakeNutrient.vitaminD), false);
      final old = food(calcium: null);
      old['nutrition'] = {
        'base_amount': 100,
        'amount_unit': 'ml',
        'calcium_mg': 0,
      };
      expect(
        NutrientDay.fromRecords([
          meal([old]),
        ], DateTime(2026, 10, 20)).totals.containsKey(IntakeNutrient.calcium),
        false,
      );
      final wrongUnits = NutrientDay.fromRecords([
        meal([food(unit: 'g')]),
      ], DateTime(2026, 10, 20));
      expect(wrongUnits.totals, isEmpty);
    },
  );
  test(
    'manual calories do not fabricate micronutrients or reuse same-name food values',
    () {
      final records = [
        meal([food()]),
        meal([], id: 'manual', extra: {'energy_kcal': 200}),
      ];
      final day = NutrientDay.fromRecords(records, DateTime(2026, 10, 20));
      expect(day.foodCount, 2);
      expect(day.known[IntakeNutrient.calcium], 1);
      expect(day.totals[IntakeNutrient.calcium], 160);
    },
  );
  test(
    'completion follows persisted content, invalidates additions/edits and never counts absent dates',
    () {
      final original = meal([food(amount: 1000)]);
      final day = NutrientDay.fromRecords([original], DateTime(2026, 10, 20));
      expect(day.fulfilled(IntakeNutrient.calcium, 800), false);
      final saved = original.copyWith(
        data: {...original.data, 'nutrition_day_signature': day.signature},
      );
      final complete = NutrientDay.fromRecords([saved], DateTime(2026, 10, 20));
      expect(complete.complete, true);
      expect(complete.fulfilled(IntakeNutrient.calcium, 800), true);
      final changed = saved.copyWith(
        data: {
          ...saved.data,
          'items': [food(amount: 500)],
        },
      );
      expect(
        NutrientDay.fromRecords([changed], DateTime(2026, 10, 20)).complete,
        false,
      );
      expect(
        NutrientDay.fromRecords([
          saved,
          meal([], id: 'new'),
        ], DateTime(2026, 10, 20)).complete,
        false,
      );
      expect(
        NutrientDay.fromRecords([saved], DateTime(2026, 10, 21)).complete,
        false,
      );
    },
  );
}
