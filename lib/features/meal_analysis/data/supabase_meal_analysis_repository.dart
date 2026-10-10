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
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'analyze-meal-image',
        body: {'storagePath': path, 'locale': 'ko-KR'},
      );
    } on FunctionException catch (error) {
      await _removeUploadedPhoto(path);
      throw StateError(_functionErrorMessage(error, 'AI 분석'));
    } catch (_) {
      await _removeUploadedPhoto(path);
      rethrow;
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final foods = [
      for (final value in data['foods'] as List? ?? const [])
        _foodFromJson(Map<String, dynamic>.from(value as Map)),
    ];
    return MealAnalysisResult(photoPath: path, foods: foods);
  }

  @override
  Future<void> discardPhoto(String? photoPath) async {
    final userId = _client.auth.currentUser?.id;
    if (photoPath == null ||
        userId == null ||
        !photoPath.startsWith('$userId/')) {
      return;
    }
    try {
      await _client.storage.from('meals').remove([photoPath]);
    } on StorageException {
      // Best-effort cleanup for a photo that was never saved as a meal.
    }
  }

  @override
  Future<List<FoodCandidate>> searchNutrition(String query) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'nutrition-search',
        body: {'query': query, 'locale': 'ko-KR'},
      );
    } on FunctionException catch (error) {
      throw StateError(_functionErrorMessage(error, '영양정보 검색'));
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    return [
      for (final value in data['candidates'] as List? ?? const [])
        _foodFromJson(Map<String, dynamic>.from(value as Map)),
    ];
  }

  @override
  Future<FoodCandidate?> lookupBarcode(String barcode) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'product-barcode',
        body: {'barcode': barcode},
      );
    } on FunctionException catch (error) {
      throw StateError(_functionErrorMessage(error, '제품 조회'));
    }
    if (response.status < 200 || response.status >= 300) {
      throw StateError('제품 조회에 실패했습니다. (${response.status})');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['product'] == null) return null;
    return _foodFromJson(Map<String, dynamic>.from(data['product'] as Map));
  }

  Future<void> _removeUploadedPhoto(String path) async {
    try {
      await _client.storage.from('meals').remove([path]);
    } on StorageException {
      // The original analysis error is more useful to the user than cleanup.
    }
  }

  String _functionErrorMessage(FunctionException error, String action) {
    final details = error.details;
    final code = details is Map
        ? (details['error'] ?? details['code'])?.toString()
        : null;
    return switch (code) {
      'NOT_FOUND' => '$action 서버가 아직 준비되지 않았어요. 사진 분석이나 직접 입력을 이용해 주세요.',
      'invalid_barcode' => '바코드 번호를 확인해 주세요.',
      'product_lookup_unavailable' => '제품 정보 서버에 연결하지 못했어요. 잠시 후 다시 시도해 주세요.',
      'product_nutrition_missing' =>
        '이 제품에는 영양정보가 등록되지 않았어요. 사진 분석이나 직접 입력을 이용해 주세요.',
      'ai_free_quota_exhausted' =>
        'Gemini 무료 사용 한도를 모두 사용했어요. 한도가 초기화된 뒤 다시 시도해 주세요.',
      'ai_not_configured' => 'AI 서버 설정이 완료되지 않았어요.',
      'invalid_session' ||
      'authentication_required' => '로그인 세션이 만료됐어요. 다시 로그인해 주세요.',
      'image_not_found' => '업로드한 사진을 찾지 못했어요. 사진을 다시 선택해 주세요.',
      'unsupported_image_size' => '사진 용량이 너무 커요. 더 작은 사진을 선택해 주세요.',
      _ when error.status == 0 => '서버에 연결하지 못했어요. 인터넷 연결을 확인해 주세요.',
      _ => '$action 요청에 실패했어요. 잠시 후 다시 시도해 주세요.',
    };
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
