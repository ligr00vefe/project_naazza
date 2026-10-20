import '../../records/domain/health_record.dart';

class RecordedHealthState {
  const RecordedHealthState(this.record, this.symptoms);
  final HealthRecord record;
  final Set<String> symptoms;
  String get label => symptoms.isEmpty ? '이상 없음' : symptoms.join(' · ');
  String get kind => record.type == HealthRecordType.bowel ? '배변' : '컨디션';

  static RecordedHealthState? read(HealthRecord r) {
    if (r.type == HealthRecordType.condition) {
      if (r.data['response_status'] == 'normal') {
        return RecordedHealthState(r, {});
      }
      if (r.data['response_status'] != 'symptom') return null;
      final symptoms = (r.data['symptoms'] as List? ?? [])
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .toSet();
      // An explicitly ended symptom is retained as an event but is not active.
      final details = r.data['symptom_events'] as Map? ?? {};
      final active = symptoms
          .where(
            (s) =>
                (details[s] is! Map) || (details[s] as Map)['phase'] != 'ended',
          )
          .toSet();
      return active.isEmpty ? null : RecordedHealthState(r, active);
    }
    if (r.type != HealthRecordType.bowel) return null;
    final symptoms = <String>{
      if (r.data['had_bowel_movement'] == false ||
          r.data['constipation'] == true)
        '변비',
      if (r.data['blood_in_stool'] == true) '혈변',
      if (['약간', '보통', '심함'].contains(r.data['pain'])) '복통',
      if ([1, 2].contains(r.data['bristol_type'])) '단단한 배변',
      if ([6, 7].contains(r.data['bristol_type'])) '묽은 배변',
    };
    // Absence of a blood/pain field in older records is not a normal response.
    final explicitNormal =
        r.data['had_bowel_movement'] == true &&
        r.data['constipation'] == false &&
        r.data['blood_in_stool'] == false &&
        r.data['pain'] == '없음' &&
        r.data['urgency'] == '없음' &&
        [3, 4].contains(r.data['bristol_type']);
    return symptoms.isNotEmpty || explicitNormal
        ? RecordedHealthState(r, symptoms)
        : null;
  }
}

/// Explicit recorded states only. Temporal observation lives in food_observation.
class HealthPatterns {
  const HealthPatterns({required this.states});
  final List<RecordedHealthState> states;
  factory HealthPatterns.fromRecords(
    Iterable<HealthRecord> input, {
    DateTime? now,
  }) {
    final end = now ?? DateTime.now();
    final start = end.subtract(const Duration(days: 30));
    final records =
        input
            .where(
              (r) =>
                  !r.recordedAt.isBefore(start) && !r.recordedAt.isAfter(end),
            )
            .toList()
          ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return HealthPatterns(
      states: records
          .map(RecordedHealthState.read)
          .whereType<RecordedHealthState>()
          .toList(),
    );
  }
}
