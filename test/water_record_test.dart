import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:naazza/app/theme/app_theme.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/data/records_repository.dart';
import 'package:naazza/features/records/domain/health_record.dart';
import 'package:naazza/features/records/domain/water_record.dart';
import 'package:naazza/features/records/presentation/water_cup_rating.dart';
import 'package:naazza/features/records/presentation/water_record_page.dart';
import 'package:naazza/features/records/presentation/records_calendar_page.dart';
import 'package:naazza/features/records/presentation/records_controller.dart';

HealthRecord water(
  String id,
  DateTime at,
  int cups, {
  String user = 'demo-user',
}) => HealthRecord(
  id: id,
  userId: user,
  type: HealthRecordType.water,
  recordedAt: at,
  title: '물',
  summary: '',
  data: {'cups': cups},
);

class FailingWaterRepo extends DemoRecordsRepository {
  bool fail = true;
  @override
  Future<HealthRecord> create(HealthRecord record) async {
    if (fail) throw StateError('offline');
    return super.create(record);
  }
}

void main() {
  test('only integer cups 0 through 7 are valid', () {
    for (var i = 0; i <= 7; i++) {
      expect(requireWaterCups(i), i);
    }
    for (final value in [-1, 8, 3.5, 4.0, '4', null]) {
      expect(() => requireWaterCups(value), throwsFormatException);
    }
  });
  test(
    'daily total upsert is stable, normalized and isolated by account',
    () async {
      final repo = DemoRecordsRepository();
      final first = await repo.create(water('a', DateTime(2026, 10, 20, 8), 3));
      final next = await repo.create(water('b', DateTime(2026, 10, 20, 20), 5));
      expect(next.id, first.id);
      expect(next.data['cups'], 5);
      expect(next.recordedAt, DateTime(2026, 10, 20));
      await repo.create(
        water('other', DateTime(2026, 10, 20), 7, user: 'other'),
      );
      expect((await repo.list('demo-user')).length, 1);
      expect((await repo.list('other')).single.data['cups'], 7);
      final zero = await repo.update(next.copyWith(data: {'cups': 0}));
      expect(zero.summary, '0컵');
      await repo.delete('demo-user', zero);
      expect(await repo.list('demo-user'), isEmpty);
      expect((await repo.list('other')).length, 1);
    },
  );
  test(
    'editing onto another recorded date never overwrites its total',
    () async {
      final repo = DemoRecordsRepository();
      final a = await repo.create(water('a', DateTime(2026, 10, 19), 4));
      await repo.create(water('b', DateTime(2026, 10, 20), 6));
      await expectLater(
        repo.update(a.copyWith(recordedAt: DateTime(2026, 10, 20))),
        throwsStateError,
      );
      expect(
        (await repo.list('demo-user')).map((r) => r.data['cups']).toSet(),
        {4, 6},
      );
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets('seven cups tap and drag in both directions at scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final value = ValueNotifier(0);
      addTearDown(value.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: ValueListenableBuilder<int>(
                  valueListenable: value,
                  builder: (_, v, _) => WaterCupRating(
                    value: v,
                    onChanged: (next) => value.value = next,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('water-cup-4')));
      await tester.pump();
      expect(value.value, 4);
      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((p) => p.painter is WaterGlassPainter)
          .map((p) => p.painter! as WaterGlassPainter)
          .toList();
      expect(painters.length, 7);
      expect(painters.where((p) => p.filled).length, 4);
      final area = find.byKey(const ValueKey('water-cup-rating')),
          left = tester.getTopLeft(area),
          size = tester.getSize(area);
      final gesture = await tester.startGesture(
        left + Offset(size.width * .5, 40),
      );
      await gesture.moveTo(left + Offset(size.width + 80, 40));
      await tester.pump();
      expect(value.value, 7);
      await gesture.moveTo(left + const Offset(-40, 40));
      await tester.pump();
      expect(value.value, 0);
      await gesture.up();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('reopen restores total and saving replaces it including zero', (
    tester,
  ) async {
    final auth = DemoAuthRepository(), repo = DemoRecordsRepository();
    final past = waterDay(DateTime.now().subtract(const Duration(days: 1)));
    await tester.runAsync(() async {
      await auth.signIn(username: 'tester', pin: '1234');
      await repo.create(water('a', past, 5));
    });
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/water',
          builder: (_, _) => WaterRecordPage(initialRecordedAt: past),
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
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/water');
    await tester.pumpAndSettle();
    expect(find.text('5컵'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('water-cup-2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('water-save')));
    await tester.pumpAndSettle();
    expect((await repo.list('demo-user')).single.data['cups'], 2);
    router.push('/water');
    await tester.pumpAndSettle();
    expect(find.text('2컵'), findsOneWidget);
    await tester.tap(find.text('선택 지우기'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('water-save')));
    await tester.pumpAndSettle();
    final saved = (await repo.list('demo-user')).single;
    expect(saved.data['cups'], 0);
    expect(saved.id, 'a');
    expect(saved.recordedAt, past);
    expect(tester.takeException(), isNull);
  });
  testWidgets('save failure retains selection and permits retry', (
    tester,
  ) async {
    final auth = DemoAuthRepository(), repo = FailingWaterRepo();
    await tester.runAsync(() => auth.signIn(username: 'tester', pin: '1234'));
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/water', builder: (_, _) => const WaterRecordPage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          recordsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/water');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('water-cup-7')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('water-save')));
    await tester.pumpAndSettle();
    expect(find.text('7컵'), findsOneWidget);
    expect(find.text('7컵 저장'), findsOneWidget);
    expect(find.byType(WaterRecordPage), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.byKey(const ValueKey('water-save')));
    await tester.pumpAndSettle();
    expect((await repo.list('demo-user')).single.data['cups'], 7);
    expect(tester.takeException(), isNull);
  });
  testWidgets('calendar shows explicit zero water and filtering hides it', (
    tester,
  ) async {
    final auth = DemoAuthRepository(), repo = DemoRecordsRepository();
    final today = waterDay(DateTime.now());
    await tester.runAsync(() async {
      await auth.signIn(username: 'tester', pin: '1234');
      await repo.create(water('w', today, 0));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          recordsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RecordsCalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final marker = find.byKey(ValueKey('water-marker-${today.day}'));
    expect(marker, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calendar-filter')));
    await tester.pumpAndSettle();
    final filter = find.widgetWithText(CheckboxListTile, '물 기록 표시하기');
    await tester.ensureVisible(filter);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();
    expect(marker, findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('controller does not duplicate records after daily upsert', (
    tester,
  ) async {
    final auth = DemoAuthRepository(), repo = DemoRecordsRepository();
    await tester.runAsync(() => auth.signIn(username: 'tester', pin: '1234'));
    late WidgetRef current;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          recordsRepositoryProvider.overrideWithValue(repo),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            current = ref;
            ref.watch(recordsProvider);
            return const MaterialApp(home: Scaffold());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final controller = current.read(recordsProvider.notifier),
        day = DateTime(2026, 10, 20);
    await controller.saveWater(water('a', day, 3), editing: false);
    await controller.saveWater(water('b', day, 7), editing: false);
    await tester.pumpAndSettle();
    expect(current.read(recordsProvider).value!.length, 1);
    expect(current.read(recordsProvider).value!.single.data['cups'], 7);
  });
}
