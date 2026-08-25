import 'dart:typed_data';
import '../domain/meal_analysis.dart';
import 'meal_analysis_repository.dart';

class DemoMealAnalysisRepository implements MealAnalysisRepository {
  @override
  Future<MealAnalysisResult> analyze({
    required String userId,
    required Uint8List imageBytes,
    required String filename,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return const MealAnalysisResult(
      photoPath: 'demo/meal.jpg',
      foods: [
        FoodCandidate(
          name: '제육볶음',
          normalizedName: '돼지고기 제육볶음',
          confidence: 0.92,
          tags: ['돼지고기', '매운음식', '볶음'],
          nutrition: NutritionFacts(
            baseAmountG: 100,
            energyKcal: 185,
            carbohydrateG: 8,
            proteinG: 14,
            fatG: 11,
            sodiumMg: 420,
          ),
          amountG: 120,
        ),
        FoodCandidate(
          name: '밥',
          normalizedName: '흰쌀밥',
          confidence: 0.95,
          tags: ['쌀', '탄수화물'],
          nutrition: NutritionFacts(
            baseAmountG: 100,
            energyKcal: 143,
            carbohydrateG: 31,
            proteinG: 2.7,
            fatG: 0.3,
            sodiumMg: 2,
          ),
          amountG: 210,
        ),
        FoodCandidate(
          name: '김치',
          normalizedName: '배추김치',
          confidence: 0.63,
          tags: ['채소', '발효식품', '매운음식'],
          nutrition: NutritionFacts(
            baseAmountG: 100,
            energyKcal: 25,
            carbohydrateG: 4,
            proteinG: 2,
            fatG: 0.5,
            sodiumMg: 650,
          ),
          amountG: 40,
        ),
      ],
    );
  }

  @override
  Future<List<FoodCandidate>> searchNutrition(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return [
      FoodCandidate(
        name: query,
        normalizedName: query,
        confidence: 1,
        tags: const ['직접검색'],
        nutrition: const NutritionFacts(
          baseAmountG: 100,
          energyKcal: 100,
          carbohydrateG: 10,
          proteinG: 5,
          fatG: 4,
          sodiumMg: 100,
        ),
      ),
    ];
  }

  @override
  Future<FoodCandidate?> lookupBarcode(String barcode) async => FoodCandidate(
    name: '데모 통밀 크래커',
    normalizedName: '통밀 크래커',
    confidence: 1,
    amountG: 30,
    tags: const ['가공식품', '밀'],
    nutrition: const NutritionFacts(
      baseAmountG: 100,
      energyKcal: 430,
      carbohydrateG: 68,
      proteinG: 9,
      fatG: 14,
      sodiumMg: 520,
    ),
  );
}
