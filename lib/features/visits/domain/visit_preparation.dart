import '../../records/domain/health_record.dart';

class VisitPreparation {
  const VisitPreparation({
    required this.since,
    required this.until,
    required this.meals,
    required this.symptomLogs,
    required this.bowelLogs,
    required this.normalDays,
    required this.topSymptoms,
    required this.questions,
  });
  final DateTime since, until;
  final int meals, symptomLogs, bowelLogs, normalDays;
  final Map<String, int> topSymptoms;
  final List<String> questions;

  static VisitPreparation build(
    List<HealthRecord> records,
    HealthRecord visit,
  ) {
    final previousVisits =
        records
            .where(
              (r) =>
                  r.type == HealthRecordType.visit &&
                  r.recordedAt.isBefore(visit.recordedAt),
            )
            .toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final since = previousVisits.isEmpty
        ? visit.recordedAt.subtract(const Duration(days: 30))
        : previousVisits.first.recordedAt;
    final period = records
        .where(
          (r) =>
              r.type != HealthRecordType.visit &&
              !r.recordedAt.isBefore(since) &&
              !r.recordedAt.isAfter(visit.recordedAt),
        )
        .toList();
    final symptoms = <String, int>{};
    for (final record in period.where(
      (r) => r.type == HealthRecordType.condition,
    )) {
      for (final item in List<Object?>.from(
        record.data['symptoms'] as List? ?? const [],
      )) {
        final value = item.toString();
        symptoms[value] = (symptoms[value] ?? 0) + 1;
      }
    }
    final sorted = Map.fromEntries(
      symptoms.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
    return VisitPreparation(
      since: since,
      until: visit.recordedAt,
      meals: period.where((r) => r.type == HealthRecordType.meal).length,
      symptomLogs: period
          .where(
            (r) =>
                r.type == HealthRecordType.condition &&
                r.data['response_status'] == 'symptom',
          )
          .length,
      bowelLogs: period.where((r) => r.type == HealthRecordType.bowel).length,
      normalDays: period
          .where(
            (r) =>
                r.type == HealthRecordType.condition &&
                r.data['response_status'] == 'normal',
          )
          .map(
            (r) =>
                '${r.recordedAt.year}-${r.recordedAt.month}-${r.recordedAt.day}',
          )
          .toSet()
          .length,
      topSymptoms: sorted,
      questions: List<String>.from(
        visit.data['questions'] as List? ?? const [],
      ),
    );
  }
}
