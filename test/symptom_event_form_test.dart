import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:naazza/app/theme/app_theme.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/records/data/records_repository.dart';
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/domain/health_record.dart';
import 'package:naazza/features/records/domain/record_labels.dart';
import 'package:naazza/features/records/presentation/condition_record_page.dart';
import 'package:naazza/features/records/presentation/symptom_event_fields.dart';

void main() {
  for (final phase in ['new', 'ongoing', 'ended']) {
    testWidgets(
      'condition form persists $phase and retains stable episode on edit',
      (tester) async {
        final auth = DemoAuthRepository(), repo = DemoRecordsRepository();
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final at = DateTime(yesterday.year, yesterday.month, yesterday.day, 14);
        final original = HealthRecord(
          id: 'database-id',
          userId: 'demo-user',
          type: HealthRecordType.condition,
          recordedAt: at.subtract(const Duration(hours: 1)),
          title: '복통',
          summary: '복통',
          data: {
            'response_status': 'symptom',
            'symptoms': ['복통'],
            'symptom_events': {
              '복통': {
                'phase': 'new',
                'episode_id': 'stable-client-episode',
                'started_at': at
                    .subtract(const Duration(hours: 1))
                    .toIso8601String(),
                'severity': 2,
              },
            },
          },
        );
        await tester.runAsync(() async {
          await auth.signIn(username: 'tester', pin: '1234');
          await repo.create(original);
        });
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('완료')),
            ),
            GoRoute(
              path: '/form',
              builder: (_, _) => ConditionRecordPage(
                record: phase == 'new' ? original : null,
                initialRecordedAt: at,
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(auth),
              recordsRepositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        router.push('/form');
        await tester.pumpAndSettle();
        if (phase != 'new') {
          await tester.tap(find.widgetWithText(ChoiceChip, '증상 기록'));
          await tester.pump();
          await tester.tap(find.widgetWithText(FilterChip, '복통'));
          await tester.pump();
          final fields = tester.widget<SymptomEventFields>(
            find.byType(SymptomEventFields),
          );
          fields.onChanged({
            'phase': phase,
            'episode_id': 'stable-client-episode',
            'severity': 1,
          });
          await tester.pump();
        }
        await tester.tap(find.text('기록 저장하기'));
        await tester.pumpAndSettle();
        final result = await repo.list('demo-user');
        final saved = phase == 'new'
            ? result.single
            : result.firstWhere((r) => r.id != 'database-id');
        final event = (saved.data['symptom_events'] as Map)['복통'] as Map;
        expect(event['phase'], phase);
        expect(event['episode_id'], 'stable-client-episode');
        if (phase == 'ended') expect(compactCondition(saved), '복통 종료');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'unknown symptom onset stays unknown when saving a legacy record',
    (tester) async {
      final auth = DemoAuthRepository(), repo = DemoRecordsRepository();
      final record = HealthRecord(
        id: 'legacy',
        userId: 'demo-user',
        type: HealthRecordType.condition,
        recordedAt: DateTime.now().subtract(const Duration(days: 1)),
        title: '복통',
        summary: '',
        data: {
          'response_status': 'symptom',
          'symptoms': ['복통'],
        },
      );
      await tester.runAsync(() async {
        await auth.signIn(username: 'tester', pin: '1234');
        await repo.create(record);
      });
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold()),
          GoRoute(
            path: '/form',
            builder: (_, _) => ConditionRecordPage(record: record),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            recordsRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.push('/form');
      await tester.pumpAndSettle();
      await tester.tap(find.text('기록 저장하기'));
      await tester.pumpAndSettle();
      final saved = (await repo.list('demo-user')).single;
      expect(
        ((saved.data['symptom_events'] as Map)['복통'] as Map)['phase'],
        'unknown',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
