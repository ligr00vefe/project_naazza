import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../data/records_repository.dart';
import '../domain/health_record.dart';

final recordsProvider =
    AsyncNotifierProvider<RecordsController, List<HealthRecord>>(
      RecordsController.new,
    );

class RecordsController extends AsyncNotifier<List<HealthRecord>> {
  @override
  Future<List<HealthRecord>> build() async {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return [];
    return ref.read(recordsRepositoryProvider).list(user.id);
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
