import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/features/meal_analysis/domain/meal_analysis.dart';
import 'package:naazza/features/meal_analysis/presentation/food_portion_dialog.dart';
import 'package:naazza/features/records/domain/meal_group.dart';
import 'meal_timeline_test.dart' show meal;

const product = FoodCandidate(
  name: '한글 상품',
  normalizedName: '한글 상품',
  confidence: 1,
  tags: [],
  isProduct: true,
  amountG: 200,
  nutrition: NutritionFacts(
    baseAmountG: 100,
    energyKcal: 200,
    carbohydrateG: 10,
    proteinG: 5,
    fatG: 5,
    sodiumMg: 20,
  ),
);
void main() {
  test('상품은 기본 한 개이며 수량과 소분 비율을 동시에 적용한다', () {
    expect(product.quantity, 1);
    expect(product.consumedNutrition.energyKcal, 400);
    expect(product.copyWith(quantity: 3).consumedNutrition.energyKcal, 1200);
    final split = product
        .withPortion(totalG: 200, totalKcal: 400, consumedG: 50, enabled: true)
        .copyWith(quantity: 2);
    expect(split.consumedNutrition.energyKcal, 200);
    final item = split.toRecordItem();
    expect(item['amount_g'], 100);
    expect(item['unit_amount_g'], 50);
    expect(item['quantity'], 2);
    expect(
      mealCalories(
        meal(
          'test',
          '상품',
          'breakfast',
          0,
          extra: {
            'items': [item],
          },
        ),
      ),
      200,
    );
  });
  testWidgets('상품 개수는 한 개부터 증가하고 감소하며 한 개 아래로 내려가지 않는다', (tester) async {
    var value = product;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: ProductQuantityControl(
              food: value,
              onChanged: (food) => setState(() => value = food),
            ),
          ),
        ),
      ),
    );
    expect(find.text('1개'), findsOneWidget);
    await tester.tap(find.byTooltip('개수 늘리기'));
    await tester.pump();
    expect(value.quantity, 2);
    expect(value.consumedNutrition.energyKcal, 800);
    await tester.tap(find.byTooltip('개수 줄이기'));
    await tester.pump();
    expect(value.quantity, 1);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
          .onPressed,
      isNull,
    );
  });
}
