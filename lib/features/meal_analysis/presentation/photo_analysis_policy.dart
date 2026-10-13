import '../domain/photo_failure.dart';
import 'dart:async';

Future<T> runPhotoAnalysis<T>(
  Future<T> request, {
  required void Function() onSlow,
  Duration warningAfter = const Duration(seconds: 20),
  Duration timeoutAfter = const Duration(seconds: 30),
}) async {
  final warning = Timer(warningAfter, onSlow);
  try {
    return await request.timeout(timeoutAfter);
  } finally {
    warning.cancel();
  }
}

String photoFailureMessage({
  required bool timedOut,
  required int failures,
  PhotoFailure? reason,
}) {
  if (reason != null) {
    if (failures < 2) return reason.message;
    return '${reason.message} ${reason.isTransport ? '같은 오류가 두 번 발생했어요. 잠시 후 다시 시도하거나 직접 입력해 주세요.' : '같은 사진에서 두 번 실패했어요. 다른 사진을 촬영하거나 직접 입력해 주세요.'}';
  }
  if (timedOut) {
    return failures >= 2
        ? 'AI 서버가 두 번 연속 응답하지 않았어요. 잠시 후 다시 시도하거나 사진을 첨부해 직접 입력해 주세요.'
        : '분석 시간이 초과됐어요. 다시 시도해 주세요.';
  }
  return failures >= 2
      ? '이 사진에서는 상품을 인식할 수 없어요. 재촬영 후 재시도하거나 직접 입력해 주세요.'
      : '사진 인식이 불가해요. 제품명과 영양표가 선명하게 보이도록 재촬영 후 시도해 주세요.';
}
