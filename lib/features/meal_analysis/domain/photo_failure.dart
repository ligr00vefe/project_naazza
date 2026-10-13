enum PhotoFailure {
  timeout,
  network,
  uploadFailed,
  rateLimited,
  server,
  invalidResponse,
  invalidImage,
  tooLarge,
  unsupportedImage,
  lowResolution,
  blurry,
  dark,
  glare,
  noFood,
  productUnidentified,
  unreadableLabel,
  missingNutrition,
  lowConfidence,
  unknown;

  bool get isTransport => [
    timeout,
    network,
    uploadFailed,
    rateLimited,
    server,
    invalidResponse,
  ].contains(this);
  String get message => switch (this) {
    timeout => '분석 시간이 초과됐어요. 잠시 후 다시 시도해 주세요.',
    uploadFailed => '사진을 서버에 저장하거나 불러오지 못했어요. 연결과 로그인 상태를 확인해 주세요.',
    network => '서버에 연결하지 못했어요. 인터넷 연결을 확인해 주세요.',
    rateLimited => 'AI 요청 한도에 도달했어요. 잠시 후 다시 시도하거나 직접 입력해 주세요.',
    server => 'AI 서버에서 분석에 실패했어요. 잠시 후 다시 시도해 주세요.',
    invalidResponse => 'AI 응답을 확인하지 못했어요. 다시 시도하거나 직접 입력해 주세요.',
    tooLarge => '사진 용량이 너무 커요. 더 작은 사진을 선택해 주세요.',
    invalidImage => '사진 파일을 읽을 수 없어요. 다른 사진을 선택해 주세요.',
    unsupportedImage => '지원하지 않는 사진 형식이에요. JPG 또는 PNG로 다시 선택해 주세요.',
    lowResolution => '사진 해상도가 너무 낮아요. 더 크게 촬영해 주세요.',
    blurry => '사진이 흐릿하게 보여요. 초점을 맞춰 다시 촬영해 주세요.',
    dark => '사진이 어둡게 보여요. 밝은 곳에서 다시 촬영해 주세요.',
    glare => '빛 반사로 글자를 읽기 어려워요. 촬영 각도를 바꿔 주세요.',
    noFood => '사진에서 음식이나 식품 포장을 확인하지 못했어요. 다시 촬영해 주세요.',
    productUnidentified => '상품을 확실하게 식별하지 못했어요. 제품명이 보이게 촬영해 주세요.',
    unreadableLabel => '제품명이 읽히지 않아요. 제품명을 가까이 촬영해 주세요.',
    missingNutrition => '영양표를 읽지 못했어요. 영양표를 추가로 촬영하거나 직접 입력해 주세요.',
    lowConfidence => '식별 결과가 확실하지 않아요. 다시 촬영하거나 직접 입력해 주세요.',
    unknown => '사진의 식별 실패 원인을 확인하지 못했어요. 다른 사진으로 시도하거나 직접 입력해 주세요.',
  };
  static PhotoFailure fromCode(Object? code) => switch (code) {
    'ai_timeout' || 'upload_timeout' => timeout,
    'ai_unavailable' || 'network_error' => network,
    'ai_free_quota_exhausted' || 'rate_limited' => rateLimited,
    'image_not_found' ||
    'upload_failed' ||
    'storage_path_forbidden' => uploadFailed,
    'NOT_FOUND' ||
    'ai_request_failed' ||
    'server_configuration_error' ||
    'ai_not_configured' => server,
    'ai_invalid_result' ||
    'ai_empty_result' ||
    'invalid_response' => invalidResponse,
    'unsupported_image_size' => tooLarge,
    'invalid_image' => invalidImage,
    'unsupported_image_type' => unsupportedImage,
    'low_resolution' => lowResolution,
    'blurry' => blurry,
    'too_dark' => dark,
    'glare' => glare,
    'no_food' => noFood,
    'product_unidentified' => productUnidentified,
    'product_name_unreadable' => unreadableLabel,
    'nutrition_unreadable' || 'invalid_nutrition' => missingNutrition,
    'low_confidence' => lowConfidence,
    _ => unknown,
  };
}

class PhotoAnalysisException extends StateError {
  PhotoAnalysisException(this.reason) : super(reason.message);
  final PhotoFailure reason;
}
