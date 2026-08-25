import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/meal_analysis.dart';

abstract interface class MealAnalysisRepository {
  Future<MealAnalysisResult> analyze({
    required String userId,
    required Uint8List imageBytes,
    required String filename,
  });

  Future<List<FoodCandidate>> searchNutrition(String query);
  Future<FoodCandidate?> lookupBarcode(String barcode);
}

final mealAnalysisRepositoryProvider = Provider<MealAnalysisRepository>(
  (ref) => throw StateError(
    'MealAnalysisRepository must be provided during bootstrap.',
  ),
);
