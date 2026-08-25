import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/health_record.dart';
import 'records_controller.dart';

class RecordsCalendarPage extends ConsumerStatefulWidget {
  const RecordsCalendarPage({super.key});
  @override
  ConsumerState<RecordsCalendarPage> createState() =>
      _RecordsCalendarPageState();
}

class _RecordsCalendarPageState extends ConsumerState<RecordsCalendarPage> {
  DateTime _selected = DateTime.now();
  @override
  Widget build(BuildContext context) {
    final records = ref.watch(recordsProvider).value ?? [];
    final selected = records
        .where((record) => DateUtils.isSameDay(record.recordedAt, _selected))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('기록 캘린더')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: CalendarDatePicker(
              initialDate: _selected,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              onDateChanged: (date) => setState(() => _selected = date),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '${_selected.month}월 ${_selected.day}일 기록',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (selected.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('선택한 날짜의 기록이 없어요.')),
              ),
            )
          else
            for (final record in selected)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: Icon(_icon(record.type)),
                    title: Text(record.title),
                    subtitle: Text(record.summary),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

IconData _icon(HealthRecordType type) => switch (type) {
  HealthRecordType.meal => Icons.restaurant_rounded,
  HealthRecordType.condition => Icons.health_and_safety_rounded,
  HealthRecordType.bowel => Icons.circle_rounded,
  HealthRecordType.visit => Icons.medical_services_rounded,
};
