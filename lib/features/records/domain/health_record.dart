enum HealthRecordType { meal, condition, bowel, visit }

enum ResponseStatus { symptom, normal, skipped }

class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.recordedAt,
    required this.title,
    required this.summary,
    required this.data,
  });

  final String id;
  final String userId;
  final HealthRecordType type;
  final DateTime recordedAt;
  final String title;
  final String summary;
  final Map<String, Object?> data;

  HealthRecord copyWith({
    DateTime? recordedAt,
    String? title,
    String? summary,
    Map<String, Object?>? data,
  }) => HealthRecord(
    id: id,
    userId: userId,
    type: type,
    recordedAt: recordedAt ?? this.recordedAt,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    data: data ?? this.data,
  );
}
