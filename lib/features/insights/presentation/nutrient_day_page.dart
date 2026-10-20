import '../../../core/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_page.dart';
import '../../records/presentation/records_controller.dart';
import 'nutrient_insight_card.dart';

class NutrientDayPage extends ConsumerWidget {
  const NutrientDayPage({super.key, required this.day});
  final DateTime day;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppScaffold(
    appBar: AppBar(title: AppPageTitle('${day.month}월 ${day.day}일 영양')),
    body: ref
        .watch(recordsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => const Center(child: Text('기록을 불러오지 못했어요.')),
          data: (records) => ListView(
            padding: const EdgeInsets.all(20),
            children: [NutrientInsightCard(records: records, day: day)],
          ),
        ),
  );
}
