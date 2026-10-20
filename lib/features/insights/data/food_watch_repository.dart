import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/food_observation.dart';

abstract interface class FoodWatchRepository {
  Future<List<FoodWatch>> load(String userId);
  Future<void> save(String userId, List<FoodWatch> watches);
}

class MemoryFoodWatchRepository implements FoodWatchRepository {
  final _values = <String, List<FoodWatch>>{};
  @override
  Future<List<FoodWatch>> load(String userId) async => [...?_values[userId]];
  @override
  Future<void> save(String userId, List<FoodWatch> watches) async {
    _values[userId] = [...watches];
  }
}

/// Owner-protected preferences stored separately from session tokens.
class SupabaseFoodWatchRepository implements FoodWatchRepository {
  SupabaseFoodWatchRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<FoodWatch>> load(String userId) async {
    if (client.auth.currentUser?.id != userId) throw StateError('로그인이 필요해요.');
    final row = await client
        .from('food_observation_preferences')
        .select('watches')
        .eq('user_id', userId)
        .maybeSingle();
    return (row?['watches'] as List? ?? [])
        .whereType<Map>()
        .map(FoodWatch.fromJson)
        .toList();
  }

  @override
  Future<void> save(String userId, List<FoodWatch> watches) async {
    if (client.auth.currentUser?.id != userId) throw StateError('로그인이 필요해요.');
    await client.from('food_observation_preferences').upsert({
      'user_id': userId,
      'watches': watches.map((w) => w.toJson()).toList(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

final foodWatchRepositoryProvider = Provider<FoodWatchRepository>(
  (ref) => MemoryFoodWatchRepository(),
);
final foodWatchesProvider =
    AsyncNotifierProvider<FoodWatchesController, List<FoodWatch>>(
      FoodWatchesController.new,
    );

class FoodWatchesController extends AsyncNotifier<List<FoodWatch>> {
  @override
  Future<List<FoodWatch>> build() async {
    final id = ref.watch(authStateProvider.select((s) => s.value?.id));
    return id == null ? [] : ref.read(foodWatchRepositoryProvider).load(id);
  }

  Future<void> save(List<FoodWatch> watches) async {
    final id = ref.read(authRepositoryProvider).currentUser?.id;
    if (id == null) throw StateError('로그인이 필요해요.');
    await ref.read(foodWatchRepositoryProvider).save(id, watches);
    if (ref.read(authRepositoryProvider).currentUser?.id == id) {
      state = AsyncData(watches);
    }
  }
}
