import '../domain/health_record.dart';
import '../domain/water_record.dart';
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
    if (record.type == HealthRecordType.water) {
      final index = _records.indexWhere(
        (r) =>
            r.userId == record.userId &&
            r.type == HealthRecordType.water &&
            waterDay(r.recordedAt) == waterDay(record.recordedAt),
      );
      final saved = normalizeWaterRecord(
        record,
        id: index < 0 ? null : _records[index].id,
      );
      if (index < 0) {
        _records.add(saved);
      } else {
        _records[index] = saved;
      }
      return saved;
    }
    _records.add(record);
    return record;
  }

  @override
  Future<HealthRecord> update(HealthRecord record) async {
    final index = _records.indexWhere((item) => item.id == record.id);
    if (index < 0) throw StateError('기록을 찾을 수 없습니다.');
    final saved = record.type == HealthRecordType.water
        ? normalizeWaterRecord(record)
        : record;
    if (saved.type == HealthRecordType.water &&
        _records.any(
          (r) =>
              r.userId == saved.userId &&
              r.id != saved.id &&
              r.type == HealthRecordType.water &&
              waterDay(r.recordedAt) == waterDay(saved.recordedAt),
        )) {
      throw StateError('이미 물 기록이 있는 날짜예요.');
    }
    _records[index] = saved;
    return saved;
  }

  @override
  Future<void> delete(String userId, HealthRecord record) async {
    _records.removeWhere(
      (item) => item.id == record.id && item.userId == userId,
    );
  }
}
