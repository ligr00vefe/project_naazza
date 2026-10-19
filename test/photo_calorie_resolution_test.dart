import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/features/meal_analysis/domain/meal_analysis.dart';
import 'package:naazza/features/meal_analysis/domain/photo_food_resolution.dart';
import 'package:naazza/features/records/domain/health_record.dart';
import 'package:naazza/features/records/domain/meal_group.dart';

const nucare = IdentifiedProduct(
  name: '뉴케어 당플랜 호두맛',
  amountText: '200ml',
  energyKcal: 200,
);
void main() {
  test('앞면의 용량·열량만으로 완전 영양표 없이 1개·2개·소분을 계산한다', () {
    final food = foodFromProductLabel(nucare)!;
    expect(food.amountUnit, 'ml');
    expect(food.amountG, 200);
    expect(food.consumedNutrition.energyKcal, 200);
    expect(food.copyWith(quantity: 2).consumedNutrition.energyKcal, 400);
    final half = food.withPortion(
      totalG: 200,
      totalKcal: 200,
      consumedG: 100,
      enabled: true,
    );
    expect(half.consumedNutrition.energyKcal, 100);
    final item = half.copyWith(quantity: 2).toRecordItem();
    expect(item['amount_g'], isNull);
    expect(item['amount_unit'], 'ml');
    expect((item['nutrition'] as Map)['sodium_mg'], isNull);
    final record = HealthRecord(
      id: 'new',
      userId: 'user',
      type: HealthRecordType.meal,
      recordedAt: DateTime.now(),
      title: '',
      summary: '',
      data: {
        'items': [item],
      },
    );
    expect(mealCalories(record), 200);
  });
  test('제품명만 식별된 상품은 이전 기록을 조회하지 않고 영양정보를 미확인으로 유지한다', () {
    final result = resolvePhotoFoods(
      const MealAnalysisResult(
        photoPath: null,
        foods: [],
        identifiedProducts: [IdentifiedProduct(name: '퀴노아 크래커')],
      ),
    );
    expect(result.foods, isEmpty);
    expect(result.identifiedProducts.single.energyKcal, isNull);
  });
}
