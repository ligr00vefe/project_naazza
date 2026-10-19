import 'ingredient_details_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/meal_group.dart';
import '../domain/health_record.dart';
import 'meal_photo.dart';
import 'records_controller.dart';

class MealGroupPage extends ConsumerWidget {
  const MealGroupPage({super.key, required this.group});
  final MealGroup group;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordsProvider);
    final records = (state.value ?? []).where(group.contains).toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final total = records.fold<double>(0, (sum, r) => sum + mealCalories(r));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${group.day.month}월 ${group.day.day}일 ${group.category.label}',
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.hasError
          ? const Center(child: Text('기록을 불러오지 못했어요.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '총 ${total.round()} kcal',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (records.isEmpty) const Text('이 끼니에 등록된 음식이 없어요.'),
                for (final record in records) _MealDetails(record: record),
              ],
            ),
    );
  }
}

class _MealDetails extends ConsumerWidget {
  const _MealDetails({required this.record});
  final HealthRecord record;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = record.data['photo_path']?.toString();
    final items = (record.data['items'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final date = record.recordedAt.toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (photo != null && photo.isNotEmpty) ...[
                  MealPhotoThumbnail(
                    path: photo,
                    fallback: const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    record.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      context.push('/record/meal', extra: record);
                    }
                    if (value == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('이 기록을 삭제할까요?'),
                          content: Text(record.title),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('취소'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('삭제'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref.read(recordsProvider.notifier).remove(record);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('수정')),
                    PopupMenuItem(value: 'delete', child: Text('삭제')),
                  ],
                ),
              ],
            ),
            Text(
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} · ${record.data['amount_text'] ?? ''} · ${mealCalories(record).round()} kcal',
            ),
            if (items.isNotEmpty) ...[
              const Divider(),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_itemDescription(item)),
                      TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => IngredientDetailsDialog(item: item),
                        ),
                        child: const Text('원재료 정보 보기'),
                      ),
                    ],
                  ),
                ),
            ],
            if (items.isEmpty)
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      IngredientDetailsDialog(item: {'name': record.title}),
                ),
                child: const Text('원재료 정보 보기'),
              ),
            if (record.data['small_meal'] == true) const Text('소식했어요'),
            if (record.data['memo']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(record.data['memo'].toString()),
            ],
          ],
        ),
      ),
    );
  }
}

String _itemDescription(Map item) {
  final nutrition = item['nutrition'] as Map? ?? {};
  final amount = nutritionNumber(item['amount'] ?? item['amount_g']);
  final base = nutritionNumber(
    nutrition['base_amount'] ?? nutrition['base_amount_g'],
  );
  final energy = nutritionNumber(nutrition['energy_kcal']);
  final scaled =
      item['nutrition_known'] == false ||
          energy == null ||
          !energy.isFinite ||
          amount == null ||
          !amount.isFinite ||
          base == null ||
          !base.isFinite ||
          base <= 0
      ? null
      : energy * amount / base;
  final count = item['is_product'] == true
      ? '${item['quantity'] ?? 1}개 · '
      : '';
  final unit = item['amount_unit']?.toString() ?? 'g';
  final portion = item['portioned'] == true
      ? '소분 ${item['unit_amount'] ?? item['unit_amount_g'] ?? item['amount']}$unit / 전체 ${item['total_amount'] ?? item['total_amount_g']}$unit · '
      : '';
  return '${item['name'] ?? '음식'} · $count$portion${amount == null ? '섭취량 미기록' : '${amount.round()}$unit'} · ${scaled == null ? '열량 미기록' : '${scaled.round()} kcal'}';
}
