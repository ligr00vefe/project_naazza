import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/health_record.dart';

abstract interface class RecordsRepository {
  Future<List<HealthRecord>> list(String userId);
  Future<HealthRecord> create(HealthRecord record);
  Future<HealthRecord> update(HealthRecord record);
  Future<void> delete(String userId, HealthRecord record);
}

final recordsRepositoryProvider = Provider<RecordsRepository>(
  (ref) =>
      throw StateError('RecordsRepository must be provided during bootstrap.'),
);
