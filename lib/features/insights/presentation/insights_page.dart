import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_design.dart';
import '../../../core/widgets/app_page.dart';
import '../../records/presentation/records_controller.dart';
import 'nutrient_insight_card.dart';
import 'fasting_insight_card.dart';
import 'observation_dashboard.dart';
import 'hydration_banner.dart';

class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: '인사이트',
    selectedIndex: 3,
    body: ref
        .watch(recordsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('기록을 불러오지 못했어요.')),
          data: (records) => AppPageList(
            children: [
              ObservationDashboard(records: records),
              const SizedBox(height: AppDesign.sectionGap),
              NutrientInsightCard(records: records),
              const SizedBox(height: AppDesign.sectionGap),
              FastingInsightCard(records: records),
              const SizedBox(height: AppDesign.sectionGap),
              const HydrationBanner(),
            ],
          ),
        ),
  );
}
