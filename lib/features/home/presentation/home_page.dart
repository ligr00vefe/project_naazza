import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../records/presentation/records_controller.dart';
import '../../tracking_profile/domain/tracking_catalog.dart';
import '../../tracking_profile/presentation/tracking_profile_controller.dart';
import '../../../core/widgets/naazza_mascot.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final profile = ref.watch(trackingProfileProvider).value;
    final quickMetrics =
        profile?.metrics.where((item) => item.enabled).take(4) ?? [];
    final recentRecords =
        ref.watch(recordsProvider).value?.take(3).toList() ?? [];
    final visits =
        ref
            .watch(recordsProvider)
            .value
            ?.where((record) => record.type.name == 'visit')
            .toList() ??
        [];
    final upcomingVisits =
        visits.where((record) {
          final next = DateTime.tryParse(
            record.data['next_visit_at']?.toString() ?? '',
          );
          return next != null && !next.isBefore(DateTime.now());
        }).toList()..sort(
          (a, b) => DateTime.parse(
            a.data['next_visit_at'].toString(),
          ).compareTo(DateTime.parse(b.data['next_visit_at'].toString())),
        );
    final upcomingVisit = upcomingVisits.firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NAAZZA',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '맞춤 추적 설정',
            onPressed: () => context.push('/tracking-profile'),
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: '로그아웃',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF1FAF5), Color(0xFFE8F5EE)],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('오늘도 기록해볼까요? 🌱'),
                const SizedBox(height: 10),
                Text(
                  '당신의 작은 기록이\n내일의 변화를 만들어요',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 18),
                const Chip(
                  avatar: Icon(Icons.sentiment_satisfied_alt_rounded, size: 18),
                  label: Text('평온해요'),
                ),
                const Align(
                  alignment: Alignment.centerRight,
                  child: NaazzaMascot(size: 120),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/favorites'),
                  icon: const Icon(Icons.favorite_outline_rounded),
                  label: const Text('내 음식'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/export'),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('내보내기'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text('빠른 기록', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _QuickCard(
                icon: Icons.camera_alt_rounded,
                title: '식사 기록',
                color: AppColors.primary,
                onTap: () => context.push('/record/meal-photo'),
              ),
              _QuickCard(
                icon: Icons.circle_rounded,
                title: '배변 기록',
                color: Color(0xFFE2A326),
                onTap: () => context.push('/record/bowel'),
              ),
              _QuickCard(
                icon: Icons.health_and_safety_rounded,
                title: '증상 기록',
                color: Color(0xFF8663CF),
                onTap: () => context.push('/record/condition'),
              ),
              _QuickCard(
                icon: Icons.medical_services_rounded,
                title: '내원 기록',
                color: Color(0xFF4B91D5),
                onTap: () => context.push('/record/visit'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text('나의 추적 항목', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in quickMetrics)
                Chip(
                  avatar: Icon(
                    TrackingCatalog.metric(metric.metricKey).icon,
                    size: 18,
                  ),
                  label: Text(TrackingCatalog.metric(metric.metricKey).label),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('최근 기록', style: Theme.of(context).textTheme.titleLarge),
              TextButton(
                onPressed: () => context.push('/timeline'),
                child: const Text('전체 보기'),
              ),
            ],
          ),
          if (recentRecords.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('첫 기록을 남겨보세요.'),
              ),
            )
          else
            for (final record in recentRecords)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    title: Text(record.title),
                    subtitle: Text(record.summary),
                  ),
                ),
              ),
          const SizedBox(height: 22),
          if (upcomingVisit != null) ...[
            _VisitCard(record: upcomingVisit),
            const SizedBox(height: 22),
          ],
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              leading: const CircleAvatar(
                backgroundColor: AppColors.lime,
                child: Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.primary,
                ),
              ),
              title: const Text(
                'P4 기록 인사이트',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(user?.email ?? '인증 사용자'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) context.push('/calendar');
          if (index == 2) context.push('/record');
          if (index == 3) context.push('/insights');
          if (index == 4) context.push('/settings');
        },
        destinations: [
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
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.record});
  final dynamic record;
  @override
  Widget build(BuildContext context) {
    final next = DateTime.parse(record.data['next_visit_at'].toString());
    final today = DateTime.now();
    final days = DateTime(
      next.year,
      next.month,
      next.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF3FC),
          child: Text(days == 0 ? 'D' : 'D-$days'),
        ),
        title: const Text(
          '다음 진료 준비',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${next.year}.${next.month}.${next.day} · ${record.title}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push('/visit/preparation', extra: record),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 34),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ),
  );
}
