import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naazza/app/router/app_router.dart';
import 'package:naazza/core/config/app_config.dart';
import 'package:naazza/app/theme/app_theme.dart';
import 'package:naazza/core/widgets/record_datetime_field.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/data/records_repository.dart';
import 'package:naazza/features/records/domain/health_record.dart';
import 'package:naazza/features/records/domain/record_draft_date.dart';
import 'package:naazza/features/tracking_profile/domain/tracking_profile.dart';
import 'package:naazza/features/tracking_profile/presentation/tracking_profile_controller.dart';

class ReadyProfile extends TrackingProfileController {
  @override
  Future<TrackingProfile?> build() async => const TrackingProfile(
    conditionKeys: ['custom'],
    metrics: [],
    remindersEnabled: false,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final now = DateTime.now();
  final past = DateTime(now.year, now.month, now.day - 1);
  test(
    'draft links preserve date/time, reject future days and accept older dates',
    () {
      final draft = calendarDraftTime(
        DateTime(1999, 12, 31),
        now: DateTime(2026, 10, 20, 21, 35),
      );
      expect(draft, DateTime(1999, 12, 31, 21, 35));
      final uri = Uri.parse(recordDateRoute('/record/alcohol', draft));
      expect(parseRecordDraftDate(uri.queryParameters['at']), draft);
      expect(parseRecordDraftDate('not-a-date'), isNull);
      expect(
        parseRecordDraftDate('2035-01-01T12:00:00', now: DateTime(2026)),
        isNull,
      );
    },
  );
  for (final entry in {
    '음주 기록': HealthRecordType.alcohol,
    '배변 기록': HealthRecordType.bowel,
    '컨디션·증상 기록': HealthRecordType.condition,
    '진료/내원 기록': HealthRecordType.visit,
    '식사 기록': HealthRecordType.meal,
    '물 마시기': HealthRecordType.water,
  }.entries) {
    testWidgets('real app routes save ${entry.key} on selected past day', (
      tester,
    ) async {
      final auth = DemoAuthRepository(), repo = DemoRecordsRepository();
      await tester.runAsync(() => auth.signIn(username: 'tester', pin: '1234'));
      late GoRouter router;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(supabaseUrl: '', supabasePublishableKey: ''),
            ),
            authRepositoryProvider.overrideWithValue(auth),
            recordsRepositoryProvider.overrideWithValue(repo),
            trackingProfileProvider.overrideWith(ReadyProfile.new),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                theme: AppTheme.light,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.go('/calendar');
      await tester.pumpAndSettle();
      if (past.month != now.month) {
        await tester.tap(find.byTooltip('이전 달'));
        await tester.pumpAndSettle();
      }
      final cell = find.byKey(
        ValueKey('calendar-day-${past.year}-${past.month}-${past.day}'),
      );
      await tester.ensureVisible(cell);
      await tester.tap(cell);
      await tester.pumpAndSettle();
      final add = find.byKey(const ValueKey('calendar-add-record'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(
        find.text('${past.year}.${past.month}.${past.day} 기록'),
        findsOneWidget,
      );
      final choice = find.text(entry.key);
      await tester.scrollUntilVisible(
        choice,
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(tester.element(choice), alignment: .25);
      await tester.pumpAndSettle();
      await tester.tap(choice);
      await tester.pumpAndSettle();
      if (entry.value == HealthRecordType.meal) {
        final manual = find.text('사진 없이 직접 입력하기');
        await tester.ensureVisible(manual);
        await tester.tap(manual);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '예시 음식');
      }
      if (entry.value != HealthRecordType.visit &&
          entry.value != HealthRecordType.water) {
        final field = tester.widget<RecordDateTimeField>(
          find.byType(RecordDateTimeField).first,
        );
        expect(DateUtils.dateOnly(field.value), past);
      }
      if (entry.value == HealthRecordType.water) {
        await tester.tap(find.byKey(const ValueKey('water-cup-4')));
        await tester.pump();
      }
      await tester.tap(
        find.text(entry.value == HealthRecordType.water ? '4컵 저장' : '기록 저장하기'),
      );
      await tester.pumpAndSettle();
      final saved = (await repo.list('demo-user')).single;
      expect(saved.type, entry.value);
      if (entry.value == HealthRecordType.water) expect(saved.data['cups'], 4);
      expect(DateUtils.dateOnly(saved.recordedAt.toLocal()), past);
      expect(tester.takeException(), isNull);
      // Calendar remains on the selected date beneath the record hub.
      while (router.canPop()) {
        router.pop();
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('calendar-add-record')), findsOneWidget);
      if (entry.value == HealthRecordType.alcohol) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 1500));
        await tester.pumpAndSettle();
        final future = DateTime(now.year, now.month, now.day + 1);
        if (future.month != past.month) {
          await tester.ensureVisible(find.byTooltip('다음 달'));
          await tester.tap(find.byTooltip('다음 달'));
          await tester.pumpAndSettle();
        }
        final futureCell = find.byKey(
          ValueKey('calendar-day-${future.year}-${future.month}-${future.day}'),
        );
        await tester.ensureVisible(futureCell);
        await tester.pumpAndSettle();
        await tester.tap(futureCell);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('calendar-add-record')), findsNothing);
      }
    });
  }
}
