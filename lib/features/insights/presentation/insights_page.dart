import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../records/presentation/records_controller.dart';
import '../domain/insight_summary.dart';

class InsightsPage extends ConsumerStatefulWidget {
  const InsightsPage({super.key});
  @override
  ConsumerState<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends ConsumerState<InsightsPage> {
  int _days = 30;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('인사이트')),
    body: ref
        .watch(recordsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('기록을 불러오지 못했어요.\n$error')),
          data: (records) {
            final summary = InsightSummary.fromRecords(records, days: _days);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                Text(
                  '기록을 바탕으로 나의 패턴을 살펴봐요 🌱',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('최근 7일')),
                    ButtonSegment(value: 30, label: Text('최근 30일')),
                    ButtonSegment(value: 90, label: Text('최근 90일')),
                  ],
                  selected: {_days},
                  onSelectionChanged: (value) =>
                      setState(() => _days = value.first),
                ),
                const SizedBox(height: 18),
                if (summary.totalRecords == 0)
                  _EmptyInsight(onRecord: () => context.push('/record'))
                else ...[
                  _SummaryGrid(summary: summary),
                  const SizedBox(height: 14),
                  _ActivityCard(summary: summary),
                  const SizedBox(height: 14),
                  _PatternCard(summary: summary),
                  const SizedBox(height: 14),
                  _ObservationCard(summary: summary),
                ],
                const SizedBox(height: 14),
                const Card(
                  color: Color(0xFFFFFAEB),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '이 결과는 기록에서 함께 나타난 경향이며 의학적 진단이나 인과관계를 의미하지 않아요.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: 3,
      onDestinationSelected: (index) {
        if (index == 0) context.go('/home');
        if (index == 1) context.go('/calendar');
        if (index == 2) context.go('/record');
        if (index == 4) context.go('/tracking-profile');
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_rounded), label: '홈'),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_rounded),
          label: '캘린더',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_circle_rounded),
          label: '기록하기',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_rounded),
          label: '인사이트',
        ),
        NavigationDestination(icon: Icon(Icons.menu_rounded), label: '더보기'),
      ],
    ),
  );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final InsightSummary summary;
  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 1.55,
    children: [
      _MetricCard(
        label: '기록한 날',
        value: '${summary.activeDays}일',
        color: AppColors.primary,
      ),
      _MetricCard(
        label: '기록 연속성',
        value: '${summary.consistencyPercent}%',
        color: const Color(0xFF4B91D5),
      ),
      _MetricCard(
        label: '식사 기록',
        value: '${summary.mealCount}회',
        color: const Color(0xFFE0A020),
      ),
      _MetricCard(
        label: '평온한 날',
        value: '${summary.normalDays}일',
        color: const Color(0xFFE66F72),
      ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted)),
          const Spacer(),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: color),
          ),
        ],
      ),
    ),
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.summary});
  final InsightSummary summary;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('기록 활동', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '${summary.days}일 동안 ${summary.totalRecords}개의 기록',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _ActivityPainter(summary.dailyActivity),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.summary});
  final InsightSummary summary;
  @override
  Widget build(BuildContext context) {
    final symptom = summary.topSymptoms.entries.firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('기록 요약', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            _PatternRow(
              icon: Icons.health_and_safety_outlined,
              label: '자주 기록한 증상',
              value: symptom == null
                  ? '기록 없음'
                  : '${symptom.key} ${symptom.value}회',
            ),
            _PatternRow(
              icon: Icons.circle_outlined,
              label: '평균 배변 형태',
              value: summary.averageBristol == null
                  ? '기록 없음'
                  : 'Bristol ${summary.averageBristol!.toStringAsFixed(1)}',
            ),
            _PatternRow(
              icon: Icons.local_fire_department_outlined,
              label: '평균 식사 열량',
              value: summary.averageEnergyKcal == null
                  ? '기록 없음'
                  : '${summary.averageEnergyKcal!.round()} kcal',
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternRow extends StatelessWidget {
  const _PatternRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFEAF6F0),
      child: Icon(icon, color: AppColors.primary),
    ),
    title: Text(label),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class _ObservationCard extends StatelessWidget {
  const _ObservationCard({required this.summary});
  final InsightSummary summary;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('나짜의 관찰', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (summary.observations.isEmpty)
            const Text('패턴을 보여드리려면 같은 항목을 3회 이상 기록해 주세요.')
          else
            for (final item in summary.observations)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
        ],
      ),
    ),
  );
}

class _EmptyInsight extends StatelessWidget {
  const _EmptyInsight({required this.onRecord});
  final VoidCallback onRecord;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(
            Icons.insights_rounded,
            size: 54,
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          Text('아직 분석할 기록이 없어요', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            '식사·증상·배변 기록을 남기면 기간별 패턴을 확인할 수 있어요.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: onRecord, child: const Text('첫 기록 남기기')),
        ],
      ),
    ),
  );
}

class _ActivityPainter extends CustomPainter {
  _ActivityPainter(this.values);
  final List<int> values;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = math.max(1, values.reduce(math.max));
    const gap = 3.0;
    final width = math.max(
      2.0,
      (size.width - gap * (values.length - 1)) / values.length,
    );
    final active = Paint()..color = AppColors.primary;
    final base = Paint()..color = const Color(0xFFE7EAE8);
    for (var i = 0; i < values.length; i++) {
      final height = math.max(4.0, size.height * values[i] / maxValue);
      final left = i * (width + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 0, width, size.height),
          const Radius.circular(4),
        ),
        base,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, width, height),
          const Radius.circular(4),
        ),
        active,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityPainter oldDelegate) =>
      oldDelegate.values != values;
}
