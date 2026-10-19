import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/features/insights/presentation/fasting_insight_card.dart';
import 'package:naazza/features/records/domain/health_record.dart';

void main() {
  testWidgets('month/year controls show actual count and weighted mean', (
    tester,
  ) async {
    final now = DateTime.now();
    final records = [
      for (var day = 1; day <= 8; day++)
        HealthRecord(
          id: '$day',
          userId: 'u',
          type: HealthRecordType.meal,
          recordedAt: DateTime(now.year, now.month, day, 8),
          title: '식사',
          summary: '',
          data: {},
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FastingInsightCard(records: records),
          ),
        ),
      ),
    );
    expect(find.text('계산한 구간 7회'), findsOneWidget);
    expect(find.text('평균 24시간 0분'), findsOneWidget);
    final tooltip = '${now.month}/2 · 24시간 0분 · 1구간';
    await tester.tap(
      find.byWidgetPredicate((w) => w is Tooltip && w.message == tooltip),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text(tooltip), findsOneWidget);
    Tooltip.dismissAllToolTips();
    await tester.pumpAndSettle();
    await tester.tap(find.text('연도별'));
    await tester.pumpAndSettle();
    expect(find.text('계산한 구간 7회'), findsOneWidget);
    expect(find.textContaining('기록 없음'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
