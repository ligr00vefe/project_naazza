import 'package:flutter/material.dart';
import '../domain/birth_date.dart';

class BirthDateField extends StatelessWidget {
  const BirthDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey('birth-date-picker'),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(44),
            textStyle: const TextStyle(fontSize: 13),
          ),
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(
            value == null ? '생년월일 입력' : birthDateText(value!),
            maxLines: 1,
          ),
          onPressed: !enabled
              ? null
              : () async {
                  FocusScope.of(context).unfocus();
                  final now = DateUtils.dateOnly(DateTime.now());
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        value ?? DateTime(now.year - 30, now.month, now.day),
                    firstDate: DateTime(1900),
                    lastDate: now,
                    initialDatePickerMode: DatePickerMode.year,
                    helpText: '생년월일',
                    cancelText: '취소',
                    confirmText: '선택',
                  );
                  if (picked != null) onChanged(picked);
                },
        ),
      ),
      if (value != null)
        IconButton(
          tooltip: '생년월일 삭제',
          onPressed: enabled ? () => onChanged(null) : null,
          icon: const Icon(Icons.close, size: 18),
        ),
    ],
  );
}
