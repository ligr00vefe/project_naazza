import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/data/records_repository.dart';
import 'package:naazza/features/records/domain/meal_group.dart';
import 'package:naazza/features/meal_analysis/data/demo_meal_analysis_repository.dart';
import 'package:naazza/features/meal_analysis/data/meal_analysis_repository.dart';
import 'package:naazza/features/meal_analysis/domain/meal_analysis.dart';
import 'package:naazza/features/meal_analysis/presentation/food_portion_dialog.dart';
import 'package:naazza/features/meal_analysis/presentation/meal_capture_page.dart';

const food = FoodCandidate(
  name: '큰 포장 음식',
  normalizedName: '음식',
  confidence: 1,
  tags: [],
  amountG: 500,
  nutrition: NutritionFacts(
    baseAmountG: 100,
    energyKcal: 160,
    carbohydrateG: 10,
    proteinG: 5,
    fatG: 4,
    sodiumMg: 100,
  ),
);
void main() {
  test('소분은 전체 용량 기준으로 열량과 영양값을 한 번만 비례 계산한다', () {
    final portion = food.withPortion(
      totalG: 500,
      totalKcal: 800,
      consumedG: 125,
      enabled: true,
    );
    expect(portion.nutrition.forAmount(portion.amountG).energyKcal, 200);
    expect(portion.nutrition.forAmount(portion.amountG).proteinG, 6.25);
    final item = portion.toRecordItem(sourceType: 'barcode');
    expect(item['amount_g'], 125);
    expect(item['total_amount_g'], 500);
    expect(item['total_energy_kcal'], 800);
    expect(item['portioned'], true);
    final updated = portion.withPortion(
      totalG: 500,
      totalKcal: 800,
      consumedG: 250,
      enabled: true,
    );
    expect(updated.nutrition.forAmount(updated.amountG).energyKcal, 400);
    final full = updated.copyWith(
      portioned: false,
      amountG: updated.wholeAmountG,
    );
    expect(full.nutrition.forAmount(full.amountG).energyKcal, 800);
  });
  test('전체보다 많이 먹은 양과 잘못된 숫자는 소분으로 적용하지 않는다', () {
    for (final amount in [501.0, 0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => food.withPortion(
          totalG: 500,
          totalKcal: 800,
          consumedG: amount,
          enabled: true,
        ),
        throwsArgumentError,
      );
    }
  });
  testWidgets('소분 입력은 초과량을 막고 예상 열량을 바로 보여준다', (tester) async {
    FoodCandidate? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await showDialog<FoodCandidate>(
                  context: context,
                  builder: (_) =>
                      const FoodPortionDialog(food: food, enablePortion: true),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), '600');
    await tester.tap(find.text('적용'));
    await tester.pump();
    expect(saved, isNull);
    await tester.enterText(find.byType(TextField).at(2), '125');
    await tester.pump();
    expect(find.text('섭취 열량 200.0 kcal'), findsOneWidget);
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(saved?.amountG, 125);
    expect(tester.takeException(), isNull);
  });
  testWidgets('분석 결과 소분을 적용하면 실제 저장 총열량과 상세 비율이 일치한다', (tester) async {
    final repo = DemoRecordsRepository(), auth = DemoAuthRepository();
    await tester.runAsync(() => auth.signIn(username: 'tester', pin: '1234'));
    final router = GoRouter(
      initialLocation: '/capture',
      routes: [
        GoRoute(path: '/capture', builder: (_, _) => const MealCapturePage()),
        GoRoute(
          path: '/timeline',
          builder: (_, _) => const Scaffold(body: Text('저장 완료')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          recordsRepositoryProvider.overrideWithValue(repo),
          mealAnalysisRepositoryProvider.overrideWithValue(
            DemoMealAnalysisRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('음식 검색 또는 이름만 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '집밥');
    await tester.tap(find.text('영양정보 검색'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('집밥'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('소분해서 먹었어요'));
    await tester.tap(find.text('소분해서 먹었어요'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '500');
    await tester.enterText(find.byType(TextField).at(1), '800');
    await tester.enterText(find.byType(TextField).at(2), '125');
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('식사 저장'));
    await tester.pumpAndSettle();
    final saved = (await repo.list('demo-user')).single;
    expect(saved.data['energy_kcal'], 200);
    expect(mealCalories(saved), 200);
    final item = (saved.data['items'] as List).single as Map;
    expect(item['portioned'], true);
    expect(item['total_amount_g'], 500);
    expect(item['amount_g'], 125);
    expect(tester.takeException(), isNull);
  });
}
