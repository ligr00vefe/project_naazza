import '../domain/health_record.dart';
import 'records_repository.dart';

class DemoRecordsRepository implements RecordsRepository {
  final _records = <HealthRecord>[];

  @override
  Future<List<HealthRecord>> list(String userId) async {
    final result = _records.where((record) => record.userId == userId).toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return result;
  }

  @override
  Future<HealthRecord> create(HealthRecord record) async {
    _records.add(record);
    return record;
  }

  @override
  Future<HealthRecord> update(HealthRecord record) async {
    final index = _records.indexWhere((item) => item.id == record.id);
    if (index < 0) throw StateError('기록을 찾을 수 없습니다.');
    _records[index] = record;
    return record;
  }

  @override
  Future<void> delete(String userId, HealthRecord record) async {
    _records.removeWhere(
      (item) => item.id == record.id && item.userId == userId,
    );
  }
}
