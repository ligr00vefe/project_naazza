import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../records/domain/health_record.dart';
import '../../records/presentation/records_controller.dart';

class FavoriteMealsPage extends ConsumerWidget {
  const FavoriteMealsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = (ref.watch(recordsProvider).value ?? const <HealthRecord>[])
        .where((r) => r.type == HealthRecordType.meal)
        .toList();
    final byTitle = <String, List<HealthRecord>>{};
    for (final meal in meals) {
      byTitle.putIfAbsent(meal.title, () => []).add(meal);
    }
    final groups = byTitle.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Scaffold(
      appBar: AppBar(title: const Text('내 음식')),
      body: groups.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text('식사를 기록하면 자주 먹는 음식이 여기에 모여요.'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '자주 먹는 식사를 한 번에 기록해요',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                for (final group in groups)
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.restaurant_rounded),
                      ),
                      title: Text(group.key),
                      subtitle: Text(
                        '${group.value.length}회 기록 · ${group.value.first.summary}',
                      ),
                      trailing: FilledButton(
                        onPressed: () =>
                            _recordAgain(context, ref, group.value.first),
                        child: const Text('기록'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _recordAgain(
    BuildContext context,
    WidgetRef ref,
    HealthRecord source,
  ) async {
    final user = ref.read(authRepositoryProvider).currentUser!;
    await ref
        .read(recordsProvider.notifier)
        .create(
          HealthRecord(
            id: 'meal-${DateTime.now().microsecondsSinceEpoch}',
            userId: user.id,
            type: HealthRecordType.meal,
            recordedAt: DateTime.now(),
            title: source.title,
            summary: source.summary,
            data: Map<String, Object?>.from(source.data)
              ..['favorite_source_id'] = source.id,
          ),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('현재 시간으로 식사를 기록했어요.')));
      context.pop();
    }
  }
}
