import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/features/meal_analysis/domain/photo_failure.dart';
import 'package:naazza/features/meal_analysis/presentation/photo_analysis_policy.dart';

void main() {
  test('원인 코드가 사진 품질과 서버 오류를 구분한다', () {
    expect(PhotoFailure.fromCode('ai_timeout'), PhotoFailure.timeout);
    expect(PhotoFailure.fromCode('NOT_FOUND'), PhotoFailure.server);
    expect(PhotoFailure.fromCode('image_not_found').isTransport, true);
    expect(PhotoFailure.fromCode('blurry').isTransport, false);
    expect(PhotoFailure.fromCode('ai_unavailable').isTransport, true);
    expect(PhotoFailure.fromCode('no_matching_product'), PhotoFailure.unknown);
    expect(
      PhotoFailure.fromCode('product_name_unreadable').message,
      contains('제품명'),
    );
    expect(
      PhotoFailure.fromCode('nutrition_unreadable').message,
      contains('영양표'),
    );
  });
  test('두 번 실패해도 확인된 원인을 유지한다', () {
    expect(
      photoFailureMessage(
        timedOut: false,
        failures: 2,
        reason: PhotoFailure.glare,
      ),
      contains('빛 반사'),
    );
    expect(
      photoFailureMessage(
        timedOut: true,
        failures: 2,
        reason: PhotoFailure.timeout,
      ),
      isNot(contains('상품')),
    );
    expect(
      photoFailureMessage(
        timedOut: false,
        failures: 1,
        reason: PhotoFailure.unknown,
      ),
      contains('원인을 확인하지 못'),
    );
  });
}
