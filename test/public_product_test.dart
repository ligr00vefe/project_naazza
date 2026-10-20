import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/features/meal_analysis/domain/meal_analysis.dart';
import 'package:naazza/features/meal_analysis/domain/public_product.dart';

void main() {
  Map<String, dynamic> data() => {
    'name': '테스트 제품',
    'basis': {'value': 100, 'unit': 'ml'},
    'packageSize': {'value': 200, 'unit': 'ml'},
    'nutrition': {'energyKcal': 100, 'proteinG': null},
    'source': {'recordId': 'fixture', 'referenceDate': '2026-10-01'},
  };
  const photo = IdentifiedProduct(
    name: '테스트 제품',
    amountText: '200ml',
    energyKcal: 200,
  );
  test(
    'confirmed product saves additional micronutrients without substituting zero',
    () {
      final raw = data();
      raw['nutrition'] = {
        'energyKcal': 100,
        'carbohydrateG': 10,
        'proteinG': 2,
        'fatG': 1,
        'sodiumMg': 5,
        'potassiumMg': 100,
        'phosphorusMg': null,
        'vitaminA': 30,
        'thiaminMg': .2,
        'riboflavinMg': 0,
        'niacinMg': 3,
      };
      final item = PublicProduct(
        raw,
      ).confirmedFood(photo)!.copyWith(quantity: 2).toRecordItem();
      final n = item['nutrition'] as Map;
      expect(n['potassium_mg'], 100);
      expect(n['phosphorus_mg'], isNull);
      expect(n['vitamin_a_rae'], 30);
      expect(n['thiamin_mg'], .2);
      expect(n['riboflavin_mg'], 0);
      expect(item['amount'], 400);
    },
  );
  test(
    'ingredient payload from an older source is stripped from future meal saves',
    () {
      final raw = data();
      raw['ingredients'] = {
        'rows': [
          {'ingredientText': 'old snapshot'},
        ],
      };
      final saved = PublicProduct(raw).confirmedFood(photo)!.toRecordItem();
      expect(
        (saved['nutrition_source'] as Map).containsKey('ingredients'),
        false,
      );
      expect((raw['ingredients'] as Map)['rows'], isNotEmpty);
    },
  );

  test(
    'confirmed same-unit product computes portions/count and preserves raw source',
    () {
      final food = PublicProduct(data()).confirmedFood(photo)!;
      expect(food.copyWith(quantity: 2).consumedNutrition.energyKcal, 400);
      final portion = food.withPortion(
        totalG: 200,
        totalKcal: 200,
        consumedG: 100,
        enabled: true,
      );
      expect(portion.consumedNutrition.energyKcal, 100);
      final record = portion.toRecordItem();
      expect((record['nutrition'] as Map)['protein_g'], isNull);
      expect(
        ((record['nutrition_source'] as Map)['source'] as Map)['recordId'],
        'fixture',
      );
    },
  );
  test(
    'one missing nutrient does not erase other known nutrients on portion save',
    () {
      final raw = data();
      raw['nutrition'] = {
        'energyKcal': 100,
        'proteinG': 2,
        'carbohydrateG': 10,
        'sodiumMg': null,
      };
      final food = PublicProduct(raw)
          .confirmedFood(photo)!
          .withPortion(
            totalG: 200,
            totalKcal: 200,
            consumedG: 100,
            enabled: true,
          );
      final nutrition = food.toRecordItem()['nutrition'] as Map;
      expect(nutrition['protein_g'], 4);
      expect(nutrition['carbohydrate_g'], 20);
      expect(nutrition['sodium_mg'], isNull);
      expect(food.consumedNutrition.proteinG, 2);
    },
  );
  test('same name does not resolve size/unit/calorie conflicts', () {
    expect(
      PublicProduct({
        ...data(),
        'packageSize': {'value': 300, 'unit': 'ml'},
      }).confirmedFood(photo),
      isNull,
    );
    expect(
      PublicProduct({
        ...data(),
        'basis': {'value': 100, 'unit': 'g'},
      }).confirmedFood(photo),
      isNull,
    );
    expect(
      PublicProduct({
        ...data(),
        'nutrition': {'energyKcal': 180},
      }).confirmedFood(photo),
      isNull,
    );
  });
  test('unknown size and basis do not become a default one-package amount', () {
    expect(
      PublicProduct({
        ...data(),
        'packageSize': null,
      }).confirmedFood(const IdentifiedProduct(name: '테스트 제품')),
      isNull,
    );
    expect(
      PublicProduct({...data(), 'basis': null}).confirmedFood(photo),
      isNull,
    );
    expect(
      PublicProduct({
        ...data(),
        'nutrition': {'energyKcal': null},
      }).confirmedFood(photo),
      isNull,
    );
  });
}
