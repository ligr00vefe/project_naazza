import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../records/domain/health_record.dart';
import '../../records/presentation/records_controller.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});
  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  int _days = 30;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('기록 내보내기')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '내 기록을 이동 가능한 CSV로 복사해요',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7일')),
            ButtonSegment(value: 30, label: Text('30일')),
            ButtonSegment(value: 90, label: Text('90일')),
          ],
          selected: {_days},
          onSelectionChanged: (v) => setState(() => _days = v.first),
        ),
        const SizedBox(height: 18),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'CSV에는 기록 시각, 유형, 제목, 요약이 포함됩니다. 사진 파일과 인증 정보는 포함하지 않아요.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _copyCsv(context),
          icon: const Icon(Icons.copy_all_rounded),
          label: const Text('CSV를 클립보드에 복사'),
        ),
      ],
    ),
  );
  Future<void> _copyCsv(BuildContext context) async {
    final start = DateTime.now().subtract(Duration(days: _days));
    final records = (ref.read(recordsProvider).value ?? const <HealthRecord>[])
        .where((r) => !r.recordedAt.isBefore(start))
        .toList();
    final lines = <String>['recorded_at,type,title,summary'];
    for (final record in records) {
      lines.add(
        [
          record.recordedAt.toIso8601String(),
          record.type.name,
          record.title,
          record.summary,
        ].map(_csv).join(','),
      );
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${records.length}개 기록을 복사했어요.')));
    }
  }
}

String _csv(String value) => '"${value.replaceAll('"', '""')}"';
