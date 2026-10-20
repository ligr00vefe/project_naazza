import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../data/records_repository.dart';
import '../domain/health_record.dart';
import '../domain/water_record.dart';

final recordsProvider =
    AsyncNotifierProvider<RecordsController, List<HealthRecord>>(
      RecordsController.new,
    );

class RecordsController extends AsyncNotifier<List<HealthRecord>> {
  /// Keep the loaded list and the form selection intact on network failure.
  Future<void> saveWater(HealthRecord record, {required bool editing}) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null || user.id != record.userId) {
      throw StateError('로그인이 필요해요.');
    }
    final previous = state.value ?? [];
    final repository = ref.read(recordsRepositoryProvider);
    final saved = editing
        ? await repository.update(normalizeWaterRecord(record))
        : await repository.create(normalizeWaterRecord(record));
    if (ref.read(authRepositoryProvider).currentUser?.id != user.id) return;
    state = AsyncData(
      [
        saved,
        ...previous.where(
          (r) =>
              r.id != saved.id &&
              !(r.type == HealthRecordType.water &&
                  waterDay(r.recordedAt) == waterDay(saved.recordedAt)),
        ),
      ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt)),
    );
  }

  @override
  Future<List<HealthRecord>> build() async {
    final userId = ref.watch(
      authStateProvider.select((state) => state.value?.id),
    );
    if (userId == null) return [];
    return ref.read(recordsRepositoryProvider).list(userId);
  }

  Future<void> create(HealthRecord record) async {
    final previous = state.value ?? [];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final created = await ref.read(recordsRepositoryProvider).create(record);
      return [created, ...previous]
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    });
  }

  Future<void> updateRecord(HealthRecord record) async {
    final previous = state.value ?? [];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final updated = await ref.read(recordsRepositoryProvider).update(record);
      return [
        for (final item in previous)
          if (item.id == updated.id) updated else item,
      ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    });
  }

  Future<void> remove(HealthRecord record) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    final previous = state.value ?? [];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(recordsRepositoryProvider).delete(user.id, record);
      return previous.where((item) => item.id != record.id).toList();
    });
  }
}
