import '../domain/photo_failure.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/meal_analysis.dart';
import 'meal_analysis_repository.dart';

class SupabaseMealAnalysisRepository implements MealAnalysisRepository {
  SupabaseMealAnalysisRepository(
    this._client, {
    this.uploadTimeout = const Duration(seconds: 30),
    this.analysisTimeout = const Duration(seconds: 40),
    this.cleanupTimeout = const Duration(seconds: 5),
  });
  final Duration uploadTimeout, analysisTimeout, cleanupTimeout;
  final SupabaseClient _client;

  @override
  Future<MealAnalysisResult> analyze({
    required String userId,
    required Uint8List imageBytes,
    required String filename,
  }) async {
    final path = await uploadPhoto(
      userId: userId,
      imageBytes: imageBytes,
      filename: filename,
    );
    final FunctionResponse response;
    try {
      response = await _client.functions
          .invoke(
            'analyze-meal-image',
            body: {'storagePath': path, 'locale': 'ko-KR'},
          )
          .timeout(analysisTimeout);
    } on TimeoutException {
      unawaited(_removeUploadedPhoto(path));
      throw PhotoAnalysisException(PhotoFailure.timeout);
    } on FunctionException catch (error) {
      unawaited(_removeUploadedPhoto(path));
      final details = error.details;
      final code = details is Map
          ? (details['error'] ?? details['code'])
          : null;
      if (code == 'invalid_session' || code == 'authentication_required') {
        throw StateError(_functionErrorMessage(error, 'AI 분석'));
      }
      final reason = code != null
          ? PhotoFailure.fromCode(code)
          : error.status == 0
          ? PhotoFailure.network
          : PhotoFailure.server;
      throw PhotoAnalysisException(reason);
    } catch (_) {
      unawaited(_removeUploadedPhoto(path));
      throw PhotoAnalysisException(PhotoFailure.network);
    }
    if (response.data is! Map || (response.data as Map)['foods'] is! List) {
      unawaited(_removeUploadedPhoto(path));
      throw PhotoAnalysisException(PhotoFailure.invalidResponse);
    }
    try {
      final data = Map<String, dynamic>.from(response.data as Map);
      final foods = [
        for (final value in data['foods'] as List? ?? const [])
          _foodFromJson(Map<String, dynamic>.from(value as Map)),
      ];
      return MealAnalysisResult(
        photoPath: path,
        foods: foods,
        identifiedProducts:
            (data['identifiedProducts'] is List
                    ? data['identifiedProducts'] as List
                    : const [])
                .whereType<Map>()
                .map(
                  (value) => IdentifiedProduct.tryFromJson(
                    Map<String, dynamic>.from(value),
                  ),
                )
                .whereType<IdentifiedProduct>()
                .toList(),
        failure: foods.isEmpty
            ? PhotoFailure.fromCode((data['diagnosis'] as Map?)?['code'])
            : null,
      );
    } catch (_) {
      unawaited(_removeUploadedPhoto(path));
      throw PhotoAnalysisException(PhotoFailure.invalidResponse);
    }
  }

  @override
  Future<String> uploadPhoto({
    required String userId,
    required Uint8List imageBytes,
    required String filename,
  }) async {
    final extension = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : 'jpg';
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    try {
      await _client.storage
          .from('meals')
          .uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          )
          .timeout(
            uploadTimeout,
            onTimeout: () => throw PhotoAnalysisException(PhotoFailure.timeout),
          );
    } on StorageException catch (error) {
      throw PhotoAnalysisException(
        error.statusCode == '413'
            ? PhotoFailure.tooLarge
            : PhotoFailure.uploadFailed,
      );
    }
    return path;
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
      await _client.storage
          .from('meals')
          .remove([photoPath])
          .timeout(cleanupTimeout);
    } catch (_) {
      // Best-effort cleanup for a photo that was never saved as a meal.
    }
  }

  @override
  Future<List<FoodCandidate>> searchNutrition(String query) async {
    final FunctionResponse response;
    try {
      response = await _client.functions
          .invoke('nutrition-search', body: {'query': query, 'locale': 'ko-KR'})
          .timeout(const Duration(seconds: 8));
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
      response = await _client.functions
          .invoke('product-barcode', body: {'barcode': barcode})
          .timeout(const Duration(seconds: 18));
    } on TimeoutException {
      throw StateError('제품 정보 조회가 지연되고 있어요. 다시 조회하거나 제품 사진으로 검색해 주세요.');
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
      await _client.storage
          .from('meals')
          .remove([path])
          .timeout(cleanupTimeout);
    } catch (_) {
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
      'public_nutrition_not_configured' ||
      'public_nutrition_authentication_failed' =>
        '영양정보 서비스 연결 설정을 확인해야 해요. 직접 입력할 수 있어요.',
      'public_nutrition_timeout' => '영양정보 조회가 지연되고 있어요. 다시 조회하거나 직접 입력해 주세요.',
      'public_nutrition_quota_exceeded' =>
        '영양정보 서비스의 조회 한도에 도달했어요. 직접 입력할 수 있어요.',
      'public_nutrition_unavailable' || 'public_nutrition_invalid_response' =>
        '영양정보에 연결하지 못했어요. 다시 조회하거나 직접 입력해 주세요.',
      'invalid_barcode' => '바코드 번호를 확인해 주세요.',
      'product_lookup_unavailable' => '제품 정보 서버에 연결하지 못했어요. 잠시 후 다시 시도해 주세요.',
      'product_nutrition_missing' =>
        '제품은 찾았지만 조회처에 열량 정보가 없어요. 제품 사진으로 검색하거나 직접 입력해 주세요.',
      'ai_free_quota_exhausted' =>
        'Gemini 무료 사용 한도를 모두 사용했어요. 한도가 초기화된 뒤 다시 시도해 주세요.',
      'ai_timeout' => '사진 분석 시간이 초과됐어요. 다시 촬영하거나 직접 입력해 주세요.',
      'ai_unavailable' => 'AI 서버에 연결하지 못했어요. 잠시 후 다시 시도해 주세요.',
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
      isProduct: json['isProduct'] == true,
      amountUnit: json['amountUnit'] as String? ?? 'g',
      hasCompleteNutrition: json['hasCompleteNutrition'] != false,
      nutritionSource: json['nutritionSource'] is Map
          ? Map<String, dynamic>.from(json['nutritionSource'] as Map)
          : null,
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
