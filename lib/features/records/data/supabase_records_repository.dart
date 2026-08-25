import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/health_record.dart';
import 'records_repository.dart';

class SupabaseRecordsRepository implements RecordsRepository {
  SupabaseRecordsRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<HealthRecord>> list(String userId) async {
    final responses = await Future.wait([
      _client.from('meals').select().eq('user_id', userId),
      _client.from('condition_logs').select().eq('user_id', userId),
      _client.from('bowel_logs').select().eq('user_id', userId),
      _client.from('visit_events').select().eq('user_id', userId),
    ]);
    final records = <HealthRecord>[
      for (final row in responses[0]) _mealFromRow(row),
      for (final row in responses[1]) _conditionFromRow(row),
      for (final row in responses[2]) _bowelFromRow(row),
      for (final row in responses[3]) _visitFromRow(row),
    ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return records;
  }

  @override
  Future<HealthRecord> create(HealthRecord record) async {
    final table = _table(record.type);
    final row = await _client
        .from(table)
        .insert(_toRow(record))
        .select()
        .single();
    return _fromRow(record.type, row);
  }

  @override
  Future<HealthRecord> update(HealthRecord record) async {
    final table = _table(record.type);
    final row = await _client
        .from(table)
        .update(_toRow(record)..remove('user_id'))
        .eq('id', record.id)
        .eq('user_id', record.userId)
        .select()
        .single();
    return _fromRow(record.type, row);
  }

  @override
  Future<void> delete(String userId, HealthRecord record) async {
    await _client
        .from(_table(record.type))
        .delete()
        .eq('id', record.id)
        .eq('user_id', userId);
  }

  String _table(HealthRecordType type) => switch (type) {
    HealthRecordType.meal => 'meals',
    HealthRecordType.condition => 'condition_logs',
    HealthRecordType.bowel => 'bowel_logs',
    HealthRecordType.visit => 'visit_events',
  };

  Map<String, Object?> _toRow(HealthRecord record) => switch (record.type) {
    HealthRecordType.meal => {
      'user_id': record.userId,
      'eaten_at': record.recordedAt.toIso8601String(),
      'meal_type': record.data['meal_type'],
      'food_name': record.title,
      'amount_text': record.data['amount_text'],
      'energy_kcal': record.data['energy_kcal'],
      'memo': record.data['memo'],
    },
    HealthRecordType.condition => {
      'user_id': record.userId,
      'recorded_at': record.recordedAt.toIso8601String(),
      'response_status': record.data['response_status'],
      'symptoms': record.data['symptoms'],
      'memo': record.data['memo'],
    },
    HealthRecordType.bowel => {
      'user_id': record.userId,
      'recorded_at': record.recordedAt.toIso8601String(),
      'bristol_type': record.data['bristol_type'],
      'urgency': record.data['urgency'],
      'pain': record.data['pain'],
      'amount': record.data['amount'],
      'memo': record.data['memo'],
    },
    HealthRecordType.visit => {
      'user_id': record.userId,
      'visit_at': record.recordedAt.toIso8601String(),
      'visit_type': record.data['visit_type'],
      'facility_label': record.data['facility_label'],
      'next_visit_at': record.data['next_visit_at'],
      'memo': record.data['memo'],
      'details': record.data,
    },
  };

  HealthRecord _fromRow(HealthRecordType type, Map<String, dynamic> row) =>
      switch (type) {
        HealthRecordType.meal => _mealFromRow(row),
        HealthRecordType.condition => _conditionFromRow(row),
        HealthRecordType.bowel => _bowelFromRow(row),
        HealthRecordType.visit => _visitFromRow(row),
      };

  HealthRecord _mealFromRow(Map<String, dynamic> row) => HealthRecord(
    id: row['id'].toString(),
    userId: row['user_id'] as String,
    type: HealthRecordType.meal,
    recordedAt: DateTime.parse(row['eaten_at'] as String),
    title: row['food_name'] as String,
    summary: '${row['amount_text'] ?? ''} · ${row['energy_kcal'] ?? 0} kcal',
    data: Map<String, Object?>.from(row),
  );

  HealthRecord _conditionFromRow(Map<String, dynamic> row) {
    final status = row['response_status'] as String;
    final symptoms = List<String>.from(row['symptoms'] as List? ?? const []);
    return HealthRecord(
      id: row['id'].toString(),
      userId: row['user_id'] as String,
      type: HealthRecordType.condition,
      recordedAt: DateTime.parse(row['recorded_at'] as String),
      title: status == 'normal'
          ? '평온해요'
          : status == 'skipped'
          ? '건너뛰기'
          : '증상 기록',
      summary: symptoms.isEmpty ? '특별한 증상 없음' : symptoms.join(', '),
      data: Map<String, Object?>.from(row),
    );
  }

  HealthRecord _bowelFromRow(Map<String, dynamic> row) => HealthRecord(
    id: row['id'].toString(),
    userId: row['user_id'] as String,
    type: HealthRecordType.bowel,
    recordedAt: DateTime.parse(row['recorded_at'] as String),
    title: '배변 기록',
    summary: 'Bristol ${row['bristol_type']} · ${row['amount'] ?? '보통'}',
    data: Map<String, Object?>.from(row),
  );

  HealthRecord _visitFromRow(Map<String, dynamic> row) {
    final details = Map<String, Object?>.from(
      row['details'] as Map? ?? const {},
    );
    details.addAll({
      'visit_type': row['visit_type'],
      'facility_label': row['facility_label'],
      'next_visit_at': row['next_visit_at'],
      'memo': row['memo'],
    });
    return HealthRecord(
      id: row['id'].toString(),
      userId: row['user_id'].toString(),
      type: HealthRecordType.visit,
      recordedAt: DateTime.parse(row['visit_at'].toString()),
      title: row['facility_label']?.toString().isNotEmpty == true
          ? row['facility_label'].toString()
          : '진료/내원',
      summary: row['memo']?.toString().isNotEmpty == true
          ? row['memo'].toString()
          : '진료 기록',
      data: details,
    );
  }
}
