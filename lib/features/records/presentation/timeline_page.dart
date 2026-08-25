import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../domain/health_record.dart';
import 'records_controller.dart';

class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});
  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  HealthRecordType? _filter;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordsProvider);
    final records =
        state.value
            ?.where((record) => _filter == null || record.type == _filter)
            .toList() ??
        [];
    return Scaffold(
      appBar: AppBar(title: const Text('타임라인')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('전체'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                const SizedBox(width: 8),
                for (final type in HealthRecordType.values) ...[
                  ChoiceChip(
                    label: Text(_typeLabel(type)),
                    selected: _filter == type,
                    onSelected: (_) => setState(() => _filter = type),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : records.isEmpty
                ? const _EmptyRecords()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _RecordCard(record: records[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/record'),
        icon: const Icon(Icons.add),
        label: const Text('기록하기'),
      ),
    );
  }
}

class _RecordCard extends ConsumerWidget {
  const _RecordCard({required this.record});
  final HealthRecord record;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      leading: CircleAvatar(
        backgroundColor: _typeColor(record.type).withValues(alpha: 0.14),
        child: Icon(_typeIcon(record.type), color: _typeColor(record.type)),
      ),
      title: Text(
        record.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${_time(record.recordedAt)}  ${record.summary}'),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'edit') {
            context.push(_editPath(record.type), extra: record);
          }
          if (value == 'delete') {
            await ref.read(recordsProvider.notifier).remove(record);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('수정')),
          PopupMenuItem(value: 'delete', child: Text('삭제')),
        ],
      ),
    ),
  );
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.eco_outlined, size: 56, color: AppColors.leaf),
        SizedBox(height: 12),
        Text('아직 기록이 없어요'),
        Text('첫 기록을 남겨보세요.', style: TextStyle(color: AppColors.muted)),
      ],
    ),
  );
}

String _typeLabel(HealthRecordType type) => switch (type) {
  HealthRecordType.meal => '식사',
  HealthRecordType.condition => '증상',
  HealthRecordType.bowel => '배변',
  HealthRecordType.visit => '진료',
};
IconData _typeIcon(HealthRecordType type) => switch (type) {
  HealthRecordType.meal => Icons.restaurant,
  HealthRecordType.condition => Icons.health_and_safety,
  HealthRecordType.bowel => Icons.circle,
  HealthRecordType.visit => Icons.medical_services_rounded,
};
Color _typeColor(HealthRecordType type) => switch (type) {
  HealthRecordType.meal => AppColors.primary,
  HealthRecordType.condition => const Color(0xFF8969D3),
  HealthRecordType.bowel => const Color(0xFFE0A020),
  HealthRecordType.visit => const Color(0xFF4B91D5),
};
String _editPath(HealthRecordType type) => switch (type) {
  HealthRecordType.meal => '/record/meal',
  HealthRecordType.condition => '/record/condition',
  HealthRecordType.bowel => '/record/bowel',
  HealthRecordType.visit => '/record/visit',
};
String _time(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
