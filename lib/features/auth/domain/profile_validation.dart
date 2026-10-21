import 'auth_failure.dart';

bool hasProfileSex(String? value) => value == 'male' || value == 'female';

String requireProfileSex(String? value) {
  if (!hasProfileSex(value)) throw const AuthFailure('성별을 선택해 주세요.');
  return value!;
}

/// A greeting name is optional, separate from the immutable login ID.
String? normalizeDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return null;
  if (name.runes.length > 30 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
    throw const AuthFailure('이름은 줄바꿈 없이 30자 이내로 입력해 주세요.');
  }
  return name;
}
