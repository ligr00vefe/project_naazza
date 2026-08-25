import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/meal_analysis.dart';
import 'meal_analysis_repository.dart';

class SupabaseMealAnalysisRepository implements MealAnalysisRepository {
  SupabaseMealAnalysisRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<MealAnalysisResult> analyze({
    required String userId,
    required Uint8List imageBytes,
    required String filename,
  }) async {
    final extension = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : 'jpg';
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage
        .from('meals')
        .uploadBinary(
          path,
          imageBytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
    final response = await _client.functions.invoke(
      'analyze-meal-image',
      body: {'storagePath': path, 'locale': 'ko-KR'},
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('AI 분석 요청에 실패했습니다.');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final foods = [
      for (final value in data['foods'] as List? ?? const [])
        _foodFromJson(Map<String, dynamic>.from(value as Map)),
    ];
    return MealAnalysisResult(photoPath: path, foods: foods);
  }

  @override
  Future<List<FoodCandidate>> searchNutrition(String query) async {
    final response = await _client.functions.invoke(
      'nutrition-search',
      body: {'query': query, 'locale': 'ko-KR'},
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('영양정보 검색에 실패했습니다.');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    return [
      for (final value in data['candidates'] as List? ?? const [])
        _foodFromJson(Map<String, dynamic>.from(value as Map)),
    ];
  }

  @override
  Future<FoodCandidate?> lookupBarcode(String barcode) async {
    final response = await _client.functions.invoke(
      'product-barcode',
      body: {'barcode': barcode},
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('제품 조회에 실패했습니다. (${response.status})');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['product'] == null) return null;
    return _foodFromJson(Map<String, dynamic>.from(data['product'] as Map));
  }

  FoodCandidate _foodFromJson(Map<String, dynamic> json) {
    final nutrition = Map<String, dynamic>.from(
      json['nutrition'] as Map? ?? const {},
    );
    return FoodCandidate(
      name: json['displayName'] as String,
      normalizedName:
          json['normalizedName'] as String? ?? json['displayName'] as String,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      tags: List<String>.from(json['tags'] as List? ?? const []),
      nutrition: NutritionFacts(
        baseAmountG: (nutrition['baseAmountG'] as num?)?.toDouble() ?? 100,
        energyKcal: (nutrition['energyKcal'] as num?)?.toDouble() ?? 0,
        carbohydrateG: (nutrition['carbohydrateG'] as num?)?.toDouble() ?? 0,
        proteinG: (nutrition['proteinG'] as num?)?.toDouble() ?? 0,
        fatG: (nutrition['fatG'] as num?)?.toDouble() ?? 0,
        sodiumMg: (nutrition['sodiumMg'] as num?)?.toDouble() ?? 0,
      ),
      amountG: (json['amountG'] as num?)?.toDouble() ?? 100,
    );
  }
}
