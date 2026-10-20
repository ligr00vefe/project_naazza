import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/features/insights/domain/health_patterns.dart';
import 'package:naazza/features/insights/domain/food_observation.dart';
import 'package:naazza/features/insights/data/food_watch_repository.dart';
import 'package:naazza/features/records/domain/health_record.dart';

HealthRecord record(
  String id,
  HealthRecordType type,
  DateTime at, {
  String title = '돈까스',
  Map<String, Object?> data = const {},
}) => HealthRecord(
  id: id,
  userId: 'u',
  type: type,
  recordedAt: at,
  title: title,
  summary: '',
  data: data,
);
HealthRecord symptom(
  String id,
  DateTime at, {
  String phase = 'unknown',
  String name = '복통',
  String? episode,
  DateTime? start,
  int? severity,
}) => record(
  id,
  HealthRecordType.condition,
  at,
  data: {
    'response_status': 'symptom',
    'symptoms': [name],
    'symptom_events': {
      name: {
        'phase': phase,
        'episode_id': episode,
        if (start != null) 'started_at': start.toIso8601String(),
        'severity': severity,
      },
    },
  },
);
void main() {
  final clock = DateTime(2026, 10, 25);
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 10, day, hour, minute);
  const watch = FoodWatch(
    id: 'w',
    name: '돈까스',
    aliases: ['돈까스', '돈가스'],
    symptoms: ['복통', '피로'],
  );
  List<ObservationCase> cases(
    List<HealthRecord> records, {
    FoodWatch target = watch,
    bool alcohol = false,
  }) => observationCases(
    records,
    watch: target,
    alcohol: alcohol,
    start: DateTime(2026, 10),
    end: DateTime(2026, 11),
    now: clock,
  );
  test(
    'user-confirmed aliases tolerate whitespace but never merge brands or variants',
    () {
      expect(watch.matches(' 돈 까스 '), isTrue);
      expect(watch.matches('치즈돈까스'), isFalse);
      expect(watch.matches('해태 돈까스'), isFalse);
      expect(FoodWatch.fromJson(watch.toJson()).aliases, watch.aliases);
    },
  );
  test(
    'immediate symptoms and all subsequent records survive intervening meals',
    () {
      final result = cases([
        record('m', HealthRecordType.meal, at(20, 12)),
        symptom('a', at(20, 12), phase: 'new', episode: 'a'),
        record('other', HealthRecordType.meal, at(20, 18), title: '밥'),
        symptom('b', at(20, 20), name: '피로', phase: 'new', episode: 'b'),
      ]).single;
      expect(result.newSymptoms.map((p) => p.record.id), ['a', 'b']);
      expect(result.context.single.id, 'other');
    },
  );
  test('window is local ingestion day plus next day, not 24 hours', () {
    final result = cases([
      record('m', HealthRecordType.meal, at(20, 0)),
      symptom('late', at(21, 23), phase: 'new', episode: 'late'),
      symptom('outside', at(22, 0), phase: 'new', episode: 'out'),
    ]).single;
    expect(result.newSymptoms.single.record.id, 'late');
    expect(result.points.any((p) => p.record.id == 'outside'), isFalse);
  });
  test('three-day linked episode preserves end and counts one new onset', () {
    final result = cases([
      record('m', HealthRecordType.meal, at(20, 12)),
      symptom('a', at(20, 12, 5), phase: 'new', episode: 'episode'),
      symptom('b', at(21, 10), phase: 'ongoing', episode: 'episode'),
      symptom('c', at(23, 8), phase: 'ended', episode: 'episode'),
    ]).single;
    expect(result.newSymptoms.length, 1);
    expect(result.points.map((p) => p.phase), ['new', 'ongoing', 'ended']);
  });
  test(
    'reported onset before ingestion is existing, never a new post-meal symptom',
    () {
      final result = cases([
        record('m', HealthRecordType.meal, at(20, 12)),
        symptom('a', at(20, 13), phase: 'new', episode: 'a', start: at(20, 8)),
      ]).single;
      expect(result.newSymptoms, isEmpty);
      expect(result.hasOngoing, isTrue);
    },
  );
  test(
    'missing, skipped, old and ended data do not become normal or new onset',
    () {
      final m = record('m', HealthRecordType.meal, at(20, 12));
      expect(cases([m]).single.unknown, isTrue);
      expect(
        cases([
          m,
          record(
            'skip',
            HealthRecordType.condition,
            at(20, 13),
            data: {'response_status': 'skipped'},
          ),
        ]).single.unknown,
        isTrue,
      );
      final legacy = cases([m, symptom('legacy', at(20, 13))]).single;
      expect(legacy.newSymptoms, isEmpty);
      expect(legacy.points.single.phase, 'unknown');
      expect(
        RecordedHealthState.read(symptom('end', at(20, 14), phase: 'ended')),
        isNull,
      );
      expect(
        SymptomPoint.read(
          symptom('end', at(20, 14), phase: 'ended'),
        ).single.phase,
        'ended',
      );
    },
  );
  test('explicit normal remains a timestamp, not a period-wide absence', () {
    final result = cases([
      record('m', HealthRecordType.meal, at(20, 12)),
      record(
        'normal',
        HealthRecordType.condition,
        at(20, 13),
        data: {'response_status': 'normal'},
      ),
    ]).single;
    expect(result.unknown, isFalse);
    expect(result.newSymptoms, isEmpty);
    expect(result.states.single.record.id, 'normal');
  });
  test(
    'co-exposures share original evidence and different times stay separate',
    () {
      final result = cases([
        record('m1', HealthRecordType.meal, at(20, 12)),
        record('m2', HealthRecordType.meal, at(20, 14)),
        record('coffee', HealthRecordType.meal, at(20, 12), title: '커피'),
        symptom('shared', at(20, 15), phase: 'new', episode: 'same'),
      ]);
      expect(result.length, 2);
      expect(
        result.every((c) => c.newSymptoms.single.record.id == 'shared'),
        isTrue,
      );
      expect(
        result.every((c) => c.context.any((r) => r.id == 'coffee')),
        isTrue,
      );
    },
  );
  test('food item name is used rather than composite meal title', () {
    final result = cases([
      record(
        'm',
        HealthRecordType.meal,
        at(20, 12),
        title: '아침 외 2개',
        data: {
          'items': [
            {'name': '돈가스'},
            {'name': '밥'},
          ],
        },
      ),
    ]);
    expect(result.length, 1);
  });
  test(
    'alcohol uses all condition changes and keeps baseline and original volume',
    () {
      final result = cases([
        record(
          'drink',
          HealthRecordType.alcohol,
          at(20, 20),
          title: '맥주',
          data: {'total_ml': 500},
        ),
        record(
          'before',
          HealthRecordType.condition,
          at(20, 18),
          data: {'response_status': 'normal'},
        ),
        symptom('fatigue', at(21, 8), phase: 'new', name: '피로', episode: 'f'),
      ], alcohol: true).single;
      expect(result.sources.single.data['total_ml'], 500);
      expect(result.before!.record.id, 'before');
      expect(result.newSymptoms.single.symptom, '피로');
    },
  );
  test(
    'future records are excluded and selected symptom does not include fatigue',
    () {
      final target = FoodWatch(
        id: 'w',
        name: '돈까스',
        aliases: ['돈까스'],
        symptoms: ['복통'],
      );
      final result = cases([
        record('m', HealthRecordType.meal, at(20, 12)),
        symptom('f', at(20, 13), name: '피로'),
        record('future', HealthRecordType.meal, at(26, 12)),
      ], target: target);
      expect(result.length, 1);
      expect(result.single.points, isEmpty);
    },
  );
  test(
    'watch settings persist independently per account and deletion keeps records',
    () async {
      final repo = MemoryFoodWatchRepository();
      await repo.save('u1', [watch]);
      expect((await repo.load('u1')).single.name, '돈까스');
      expect(await repo.load('u2'), isEmpty);
      await repo.save('u1', []);
      expect(await repo.load('u1'), isEmpty);
    },
  );
}
