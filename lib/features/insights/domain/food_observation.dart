import '../../records/domain/health_record.dart';
import '../../records/domain/meal_group.dart';
import 'health_patterns.dart';

const observationSymptoms = ['복통', '복부팽만', '피로', '메스꺼움', '설사'];
String foodKey(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
DateTime localDay(DateTime value) {
  final d = value.toLocal();
  return DateTime(d.year, d.month, d.day);
}

String observationTime(DateTime value) {
  final d = value.toLocal();
  return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class FoodWatch {
  const FoodWatch({
    required this.id,
    required this.name,
    required this.aliases,
    required this.symptoms,
  });
  final String id, name;
  final List<String> aliases, symptoms;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'aliases': aliases,
    'symptoms': symptoms,
  };
  static FoodWatch fromJson(Map value) => FoodWatch(
    id: value['id'].toString(),
    name: value['name'].toString(),
    aliases: List<String>.from(value['aliases'] as List? ?? []),
    symptoms: List<String>.from(
      value['symptoms'] as List? ?? observationSymptoms,
    ),
  );
  bool matches(String value) =>
      aliases.any((a) => foodKey(a) == foodKey(value));
}

/// A point explicitly recorded by the user; legacy records have unknown onset.
class SymptomPoint {
  const SymptomPoint(
    this.record,
    this.symptom,
    this.phase,
    this.episode,
    this.at,
    this.severity,
  );
  final HealthRecord record;
  final String symptom, phase;
  final String? episode;
  final DateTime at;
  final int? severity;
  String get phaseLabel => switch (phase) {
    'new' => '새 증상',
    'ongoing' => '지속',
    'ended' => '종료',
    _ => '시작 미확인',
  };
  static List<SymptomPoint> read(HealthRecord r) {
    if (r.type == HealthRecordType.condition &&
        r.data['response_status'] != 'symptom') {
      return [];
    }
    final state = RecordedHealthState.read(r);
    final details = r.data['symptom_events'] as Map? ?? {};
    if (state == null &&
        (r.type != HealthRecordType.condition ||
            r.data['response_status'] != 'symptom')) {
      return [];
    }
    final names = {...?state?.symptoms, ...details.keys.whereType<String>()};
    return [for (final name in names) _read(r, name, details[name])];
  }

  static SymptomPoint _read(HealthRecord r, String name, Object? detail) {
    final d = detail is Map ? detail : const {};
    final phase = ['new', 'ongoing', 'ended'].contains(d['phase'])
        ? d['phase'].toString()
        : 'unknown';
    final start = DateTime.tryParse(d['started_at']?.toString() ?? '');
    final at = phase == 'new' && start != null && !start.isAfter(r.recordedAt)
        ? start
        : r.recordedAt;
    final severity = d['severity'];
    return SymptomPoint(
      r,
      name,
      phase,
      d['episode_id']?.toString(),
      at,
      severity is int && severity >= 1 && severity <= 3 ? severity : null,
    );
  }
}

class ObservationCase {
  const ObservationCase({
    required this.sources,
    required this.points,
    required this.states,
    required this.context,
    this.before,
  });
  final List<HealthRecord> sources, context;
  final List<SymptomPoint> points;
  final List<RecordedHealthState> states;
  final RecordedHealthState? before;
  DateTime get at => sources.first.recordedAt;
  DateTime get end => localDay(at).add(const Duration(days: 2));
  List<SymptomPoint> get newSymptoms => points
      .where(
        (p) => p.phase == 'new' && !p.at.isBefore(at) && p.at.isBefore(end),
      )
      .toList();
  bool get hasOngoing => points.any(
    (p) => p.phase == 'ongoing' || (p.phase == 'new' && p.at.isBefore(at)),
  );
  bool get unknown => points.isEmpty && states.isEmpty;
}

List<ObservationCase> observationCases(
  List<HealthRecord> records, {
  FoodWatch? watch,
  bool alcohol = false,
  required DateTime start,
  required DateTime end,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final all = records.where((r) => !r.recordedAt.isAfter(clock)).toList()
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  final points = all.expand(SymptomPoint.read).toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  final states = all
      .map(RecordedHealthState.read)
      .whereType<RecordedHealthState>()
      .toList();
  // Food entries at precisely the same meal time are one observed exposure.
  // Different times are kept separate; no arbitrary next-meal cutoff.
  final buckets = <String, List<HealthRecord>>{};
  for (final r in all) {
    if (r.recordedAt.isBefore(start) || !r.recordedAt.isBefore(end)) continue;
    final names = (r.data['items'] as List? ?? [])
        .whereType<Map>()
        .map((v) => v['name']?.toString() ?? '')
        .toList();
    final match = alcohol
        ? r.type == HealthRecordType.alcohol
        : r.type == HealthRecordType.meal &&
              watch != null &&
              (names.isEmpty ? [r.title] : names).any(watch.matches);
    if (match) {
      (buckets['${r.recordedAt.toUtc().toIso8601String()}-${r.data['meal_type']}'] ??=
              [])
          .add(r);
    }
  }
  return buckets.values.map((sources) {
    final at = sources.first.recordedAt,
        limit = localDay(sources.first.recordedAt).add(const Duration(days: 2));
    final nearby = points
        .where(
          (p) =>
              (watch == null || watch.symptoms.contains(p.symptom)) &&
              p.at.isBefore(limit) &&
              (!p.at.isBefore(at) ||
                  (!p.record.recordedAt.isBefore(at) &&
                      p.record.recordedAt.isBefore(limit))),
        )
        .toList();
    // Baseline only when explicitly linked to a still-active episode, not merely
    // because some unrelated symptom was entered a day before eating.
    final episodes = <String>{
      for (final p in nearby)
        if (p.episode != null) p.episode!,
    };
    for (final p in points.where(
      (p) =>
          p.phase == 'new' &&
          p.at.isBefore(at) &&
          p.episode != null &&
          (watch == null || watch.symptoms.contains(p.symptom)),
    )) {
      final closed = points.any(
        (e) =>
            e.episode == p.episode && e.phase == 'ended' && !e.at.isAfter(at),
      );
      if (!closed && nearby.any((e) => e.episode == p.episode)) {
        episodes.add(p.episode!);
      }
    }
    final included = points
        .where(
          (p) =>
              nearby.contains(p) ||
              (p.episode != null && episodes.contains(p.episode)),
        )
        .toList();
    final contextEnd = included.fold<DateTime>(
      limit,
      (last, p) => p.record.recordedAt.isAfter(last)
          ? p.record.recordedAt.add(const Duration(seconds: 1))
          : last,
    );
    return ObservationCase(
      sources: sources,
      points: included,
      before: states
          .where(
            (s) =>
                s.record.recordedAt.isBefore(at) &&
                s.record.recordedAt.difference(at).inHours >= -24,
          )
          .lastOrNull,
      states: states
          .where(
            (s) =>
                !s.record.recordedAt.isBefore(at) &&
                s.record.recordedAt.isBefore(limit),
          )
          .toList(),
      context: all
          .where(
            (r) =>
                (r.type == HealthRecordType.meal ||
                    r.type == HealthRecordType.alcohol) &&
                !r.recordedAt.isBefore(localDay(at)) &&
                r.recordedAt.isBefore(contextEnd) &&
                !sources.contains(r),
          )
          .toList(),
    );
  }).toList()..sort((a, b) => b.at.compareTo(a.at));
}

List<String> recordedFoodNames(List<HealthRecord> records) => {
  for (final g in groupMealSessions(records)) ...mealFoodNames(g),
}.where((s) => s.trim().isNotEmpty).toList()..sort();
