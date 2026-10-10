import 'visit_recents.dart';
import '../../records/domain/record_labels.dart';
import '../../../core/widgets/word_wrap_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../records/domain/health_record.dart';
import '../../records/presentation/records_controller.dart';

class VisitRecordPage extends ConsumerStatefulWidget {
  const VisitRecordPage({super.key, this.record});
  final HealthRecord? record;
  @override
  ConsumerState<VisitRecordPage> createState() => _VisitRecordPageState();
}

class _VisitRecordPageState extends ConsumerState<VisitRecordPage> {
  late DateTime _visitAt;
  DateTime? _nextVisitAt;
  String _visitType = 'regular';
  late final TextEditingController _facility,
      _department,
      _tests,
      _memo,
      _medication,
      _questions;
  bool _reminderEnabled = true;
  int _reminderDays = 3;

  @override
  void initState() {
    super.initState();
    final data = widget.record?.data;
    _visitAt = widget.record?.recordedAt ?? DateTime.now();
    _nextVisitAt = DateTime.tryParse(data?['next_visit_at']?.toString() ?? '');
    _visitType = data?['visit_type']?.toString() ?? 'regular';
    _facility = TextEditingController(
      text: data?['facility_label']?.toString() ?? '',
    );
    _department = TextEditingController(
      text: data?['department']?.toString() ?? '',
    );
    _tests = TextEditingController(text: data?['tests']?.toString() ?? '');
    _memo = TextEditingController(text: data?['memo']?.toString() ?? '');
    _medication = TextEditingController(
      text: data?['medication_changes']?.toString() ?? '',
    );
    _questions = TextEditingController(
      text: List<Object?>.from(
        data?['questions'] as List? ?? const [],
      ).join('\n'),
    );
    _reminderEnabled = data?['reminder_enabled'] as bool? ?? true;
    _reminderDays = data?['reminder_days_before'] as int? ?? 3;
  }

  @override
  void dispose() {
    _facility.dispose();
    _department.dispose();
    _tests.dispose();
    _memo.dispose();
    _medication.dispose();
    _questions.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
  );
  Future<void> _save() async {
    final user = ref.read(authRepositoryProvider).currentUser!;
    final questions = _questions.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final record = HealthRecord(
      id: widget.record?.id ?? 'visit-${DateTime.now().microsecondsSinceEpoch}',
      userId: user.id,
      type: HealthRecordType.visit,
      recordedAt: _visitAt,
      title: _facility.text.trim().isEmpty ? '진료/내원' : _facility.text.trim(),
      summary: _memo.text.trim().isEmpty
          ? _visitTypeLabel(_visitType)
          : _memo.text.trim(),
      data: {
        ...?widget.record?.data,
        'visit_type': _visitType,
        'department': _department.text.trim(),
        'facility_label': _facility.text.trim(),
        'next_visit_at': _nextVisitAt?.toIso8601String(),
        'tests': _tests.text.trim(),
        'memo': _memo.text.trim(),
        'medication_changes': _medication.text.trim(),
        'questions': questions,
        'reminder_enabled': _reminderEnabled,
        'reminder_days_before': _reminderDays,
      },
    );
    widget.record == null
        ? await ref.read(recordsProvider.notifier).create(record)
        : await ref.read(recordsProvider.notifier).updateRecord(record);
    if (mounted && !ref.read(recordsProvider).hasError) {
      ref
          .read(visitRecentsProvider.notifier)
          .remember(_facility.text, _department.text);
      FocusManager.instance.primaryFocus?.unfocus();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/calendar');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.record == null ? '진료/내원 기록' : '진료 기록 수정'),
    ),
    body: ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        WordWrapText(
          '방문한 진료 내용을 기록해요',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final value in [
              'regular',
              'checkup',
              'test',
              'consultation',
              'visit',
              'other',
            ])
              ChoiceChip(
                label: Text(visitCategory(value)),
                selected: _visitType == value,
                onSelected: (_) => setState(() => _visitType = value),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _DateTile(
          label: '진료일',
          value: _visitAt,
          onTap: () async {
            final d = await _pickDate(_visitAt);
            if (d != null) setState(() => _visitAt = d);
          },
        ),
        const SizedBox(height: 16),
        _RecentChoices(
          values: ref.watch(visitRecentsProvider).facilities,
          onSelected: (value) => _facility.text = value,
          onDeleted: (value) =>
              ref.read(visitRecentsProvider.notifier).removeFacility(value),
        ),
        TextField(
          key: const ValueKey('visit-facility'),
          controller: _facility,
          decoration: const InputDecoration(
            labelText: '병원/기관',
            prefixIcon: Icon(Icons.local_hospital_outlined),
          ),
        ),

        const SizedBox(height: 16),
        _RecentChoices(
          values: ref.watch(visitRecentsProvider).departments,
          onSelected: (value) => _department.text = value,
          onDeleted: (value) =>
              ref.read(visitRecentsProvider.notifier).removeDepartment(value),
        ),
        TextField(
          key: const ValueKey('visit-department'),
          controller: _department,
          decoration: const InputDecoration(labelText: '진료과'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _tests,
          maxLines: 2,
          decoration: const InputDecoration(labelText: '검사 및 결과'),
        ),

        const SizedBox(height: 16),
        TextField(
          controller: _memo,
          maxLines: 4,
          decoration: const InputDecoration(labelText: '상담 메모'),
        ),

        const SizedBox(height: 16),
        TextField(
          controller: _medication,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '처방 변경 사실',
            hintText: '예: 프레드니솔론 10mg → 5mg',
          ),
        ),

        const SizedBox(height: 16),
        TextField(
          controller: _questions,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '다음 진료 때 물어볼 내용',
            hintText: '질문마다 줄을 바꿔 입력해 주세요',
          ),
        ),
        const SizedBox(height: 16),
        _DateTile(
          key: const ValueKey('visit-next-date'),
          label: '다음 진료일',
          value: _nextVisitAt,
          onTap: () async {
            final d = await _pickDate(
              _nextVisitAt ?? DateTime.now().add(const Duration(days: 30)),
            );
            if (d != null) setState(() => _nextVisitAt = d);
          },
        ),
        if (_nextVisitAt != null) ...[
          const SizedBox(height: 16),
          Card(
            key: const ValueKey('visit-reminder'),
            child: SwitchListTile(
              title: const Text('진료 준비 알림'),
              subtitle: Text('진료 $_reminderDays일 전 한 번 알려드려요.'),
              value: _reminderEnabled,
              onChanged: (v) => setState(() => _reminderEnabled = v),
              secondary: const Icon(Icons.notifications_active_outlined),
            ),
          ),
        ],
        if (_nextVisitAt != null && _reminderEnabled)
          Slider(
            value: _reminderDays.toDouble(),
            min: 1,
            max: 7,
            divisions: 6,
            label: '$_reminderDays일 전',
            onChanged: (v) => setState(() => _reminderDays = v.round()),
          ),
      ],
    ),
    bottomNavigationBar: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: FilledButton(
          key: const ValueKey('visit-save'),
          onPressed: ref.watch(recordsProvider).isLoading ? null : _save,
          child: const Text('기록 저장하기'),
        ),
      ),
    ),
  );
}

class _RecentChoices extends StatelessWidget {
  const _RecentChoices({
    required this.values,
    required this.onSelected,
    required this.onDeleted,
  });
  final List<String> values;
  final ValueChanged<String> onSelected, onDeleted;
  @override
  Widget build(BuildContext context) => values.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                InputChip(
                  label: Text(value),
                  onPressed: () => onSelected(value),
                  onDeleted: () => onDeleted(value),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  deleteButtonTooltipMessage: '$value 최근 항목 삭제',
                ),
            ],
          ),
        );
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.calendar_month_rounded),
      title: Text(label),
      trailing: Text(
        value == null
            ? '선택'
            : '${value!.year}.${value!.month.toString().padLeft(2, '0')}.${value!.day.toString().padLeft(2, '0')}',
      ),
      onTap: onTap,
    ),
  );
}

String _visitTypeLabel(String type) => switch (type) {
  'regular' => '정기진료',
  'checkup' => '검진',
  'test' => '검사',
  'consultation' => '문진',
  'visit' => '방문',
  _ => '기타 진료',
};
