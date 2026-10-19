import 'package:flutter/material.dart';

class RecordDateTimeField extends StatelessWidget {
  const RecordDateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: ValueKey('$label-date'),
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('${value.year}.${value.month}.${value.day}'),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: value,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (date != null && context.mounted) {
                onChanged(
                  DateTime(
                    date.year,
                    date.month,
                    date.day,
                    value.hour,
                    value.minute,
                  ),
                );
              }
            },
          ),
          OutlinedButton.icon(
            key: ValueKey('$label-time'),
            icon: const Icon(Icons.schedule),
            label: Text(
              '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
            ),
            onPressed: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(value),
              );
              if (time != null && context.mounted) {
                onChanged(
                  DateTime(
                    value.year,
                    value.month,
                    value.day,
                    time.hour,
                    time.minute,
                  ),
                );
              }
            },
          ),
        ],
      ),
    ],
  );
}
