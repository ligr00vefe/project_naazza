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
  final failure =
      reason ?? (timedOut ? PhotoFailure.timeout : PhotoFailure.unknown);
  if (failures < 2) return failure.message;
  if (failure.isTransport) {
    return '${failure.message} 응답 문제가 반복되고 있어요. 다시 시도하거나 사진을 첨부해 직접 입력할 수 있어요.';
  }
  return '${failure.message} 사진을 바꾸면 도움이 될 수 있어요. 기존 사진을 첨부해 직접 입력할 수도 있어요.';
}
