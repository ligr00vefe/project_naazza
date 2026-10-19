import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:naazza/core/widgets/record_datetime_field.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/data/records_repository.dart';
import 'package:naazza/features/records/presentation/bowel_record_page.dart';
import 'package:naazza/features/insights/domain/insight_summary.dart';

void main() {
  testWidgets(
    'two same-day entries keep their times; no movement keeps no form and is not a bowel movement count',
    (tester) async {
      final auth = DemoAuthRepository();
      await tester.runAsync(() => auth.signIn(username: 'tester', pin: '1234'));
      final repo = DemoRecordsRepository();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/bowel'),
                child: const Text('기록 열기'),
              ),
            ),
          ),
          GoRoute(path: '/bowel', builder: (_, _) => const BowelRecordPage()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            recordsRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('기록 열기'));
      await tester.pumpAndSettle();
      tester
          .widget<RecordDateTimeField>(find.byType(RecordDateTimeField))
          .onChanged(DateTime(2026, 10, 15, 7, 30));
      await tester.pump();
      await tester.tap(find.text('변비 · 배변 못함'));
      await tester.pump();
      await tester.tap(find.text('기록 저장하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('기록 열기'));
      await tester.pumpAndSettle();
      tester
          .widget<RecordDateTimeField>(find.byType(RecordDateTimeField))
          .onChanged(DateTime(2026, 10, 15, 10, 15));
      await tester.pump();
      await tester.tap(find.text('기록 저장하기'));
      await tester.pumpAndSettle();
      final records = await repo.list('demo-user');
      expect(records.length, 2);
      expect(records.map((r) => r.recordedAt.hour).toSet(), {7, 10});
      final noMovement = records.firstWhere(
        (r) => r.data['had_bowel_movement'] == false,
      );
      expect(noMovement.data['bristol_type'], isNull);
      expect(noMovement.data['constipation'], true);
      final summary = InsightSummary.fromRecords(
        records,
        days: 30,
        now: DateTime(2026, 10, 15),
      );
      expect(summary.bowelCount, 1);
    },
  );
}
