import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../records/domain/health_record.dart';
import '../../records/presentation/records_controller.dart';
import '../domain/visit_preparation.dart';

class VisitPreparationPage extends ConsumerWidget {
  const VisitPreparationPage({super.key, required this.visit});
  final HealthRecord visit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recordsProvider).value ?? const <HealthRecord>[];
    final summary = VisitPreparation.build(records, visit);
    return Scaffold(
      appBar: AppBar(title: const Text('진료 준비 요약')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            '지난 진료 이후부터 지금까지',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '${_date(summary.since)} ~ ${_date(summary.until)}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              _CountCard(
                '식사 기록',
                '${summary.meals}회',
                Icons.restaurant_rounded,
              ),
              _CountCard(
                '증상 기록',
                '${summary.symptomLogs}건',
                Icons.health_and_safety_outlined,
              ),
              _CountCard(
                '배변 기록',
                '${summary.bowelLogs}회',
                Icons.circle_outlined,
              ),
              _CountCard(
                '평온한 날',
                '${summary.normalDays}일',
                Icons.favorite_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('주요 증상', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (summary.topSymptoms.isEmpty)
                    const Text('기록된 증상이 없어요.')
                  else
                    for (final item in summary.topSymptoms.entries.take(3))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.key),
                        trailing: Text(
                          '${item.value}회',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '의사에게 물어볼 내용',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (summary.questions.isEmpty)
                    const Text('저장한 질문이 없어요.')
                  else
                    for (final question in summary.questions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  '),
                            Expanded(child: Text(question)),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            color: Color(0xFFFFFAEB),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '이 요약은 사용자가 기록한 사실을 정리한 참고 자료이며 진단이나 치료 효과를 판단하지 않아요.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const Spacer(),
          Text(label, style: const TextStyle(color: AppColors.muted)),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );
}

String _date(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
