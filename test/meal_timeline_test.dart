import 'package:naazza/features/records/presentation/alcohol_record_page.dart';
import 'package:naazza/features/records/presentation/records_calendar_page.dart';
import 'package:naazza/features/records/presentation/record_detail_page.dart';
import 'package:naazza/features/records/presentation/bowel_record_page.dart';
import 'package:naazza/features/records/presentation/condition_record_page.dart';
import 'package:naazza/features/visits/presentation/visit_record_page.dart';
import 'package:naazza/features/insights/presentation/insights_page.dart';
import 'package:naazza/features/settings/presentation/accessibility_settings.dart';
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
import 'package:naazza/features/records/domain/meal_group.dart';
import 'package:naazza/features/records/presentation/timeline_page.dart';
import 'package:naazza/features/records/presentation/meal_group_page.dart';
import 'package:naazza/features/records/presentation/meal_record_page.dart';

HealthRecord meal(
  String id,
  String name,
  String category,
  int kcal, {
  int day = 11,
  int hour = 8,
  Map<String, Object?> extra = const {},
}) => HealthRecord(
  id: id,
  userId: 'demo-user',
  type: HealthRecordType.meal,
  recordedAt: DateTime(2026, 10, day, hour),
  title: name,
  summary: '$kcal kcal',
  data: {'meal_type': category, 'energy_kcal': kcal, ...extra},
);

Future<GoRouter> open(
  WidgetTester tester,
  DemoRecordsRepository repository, {
  String location = '/timeline',
  double scale = 1,
  HealthRecord? initialRecord,
}) async {
  final auth = DemoAuthRepository();
  await tester.runAsync(() => auth.signIn(username: 'tester', pin: '1234'));
  final router = GoRouter(
    initialLocation: location,
    initialExtra: initialRecord,
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('홈 화면')),
      ),
      GoRoute(
        path: '/calendar',
        builder: (_, _) => const RecordsCalendarPage(),
      ),
      GoRoute(
        path: '/record/alcohol',
        builder: (_, s) => AlcoholRecordPage(record: s.extra as HealthRecord?),
      ),
      GoRoute(path: '/insights', builder: (_, _) => const InsightsPage()),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const AccessibilitySettingsPage(),
      ),
      GoRoute(
        path: '/records/detail',
        builder: (_, s) => RecordDetailPage(record: s.extra! as HealthRecord),
      ),
      GoRoute(
        path: '/record/bowel',
        builder: (_, s) => BowelRecordPage(record: s.extra as HealthRecord?),
      ),
      GoRoute(
        path: '/record/visit',
        builder: (_, s) => VisitRecordPage(record: s.extra as HealthRecord?),
      ),
      GoRoute(
        path: '/record/condition',
        builder: (_, s) =>
            ConditionRecordPage(record: s.extra as HealthRecord?),
      ),
      GoRoute(path: '/timeline', builder: (_, _) => const TimelinePage()),
      GoRoute(
        path: '/timeline/meal',
        builder: (_, state) => MealGroupPage(group: state.extra! as MealGroup),
      ),
      GoRoute(
        path: '/record/meal',
        builder: (_, state) =>
            MealRecordPage(record: state.extra as HealthRecord?),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        recordsRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  test('달력의 반복 간식은 시간순으로 분리되고 상세도 해당 묶음만 포함한다', () {
    final groups = groupMealSessions([
      meal('a', '라면', 'breakfast', 500),
      meal('b', '계란', 'breakfast', 80),
      meal('c', '사과', 'snack', 90, hour: 10),
      meal('d', '우유', 'snack', 100, hour: 12),
      meal('e', '밥', 'lunch', 300, hour: 13),
      meal('f', '빵', 'snack', 200, hour: 15),
    ]);
    expect(groups.map((g) => g.category.label), ['아침', '간식', '간식', '점심', '간식']);
    expect(compactMealNames(groups.first), '라면 외 1개');
    expect(groups[1].contains(meal('d', '우유', 'snack', 100, hour: 12)), false);
  });
  testWidgets('캘린더에서 끼니 필터와 병원 날짜 표시 토글이 동작한다', (tester) async {
    final repo = DemoRecordsRepository();
    final now = DateTime.now();
    await repo.create(
      meal('a', '라면', 'breakfast', 500).copyWith(recordedAt: now),
    );
    await repo.create(meal('b', '사과', 'snack', 90).copyWith(recordedAt: now));
    await repo.create(
      HealthRecord(
        id: 'visit',
        userId: 'demo-user',
        type: HealthRecordType.visit,
        recordedAt: now,
        title: '나짜병원',
        summary: '검진',
        data: const {
          'visit_type': 'checkup',
          'facility_label': '나짜병원',
          'department': '내과',
          'tests': '검사 메모',
        },
      ),
    );
    final router = await open(tester, repo, location: '/calendar');
    addTearDown(router.dispose);
    expect(find.byKey(ValueKey('visit-marker-${now.day}')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calendar-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('아침만 보기'));
    await tester.tap(find.text('검진 기록 표시하기'));
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('visit-marker-${now.day}')), findsNothing);
    await tester.scrollUntilVisible(
      find.text('아침 · 라면'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('간식 · 사과'), findsNothing);
    await tester.tap(find.text('아침 · 라면'));
    await tester.pumpAndSettle();
    expect(find.text('총 500 kcal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('배변 상세의 시간과 통증을 확인하고 수정하면 다시 반영된다', (tester) async {
    final repo = DemoRecordsRepository();
    final record = HealthRecord(
      id: 'bowel',
      userId: 'demo-user',
      type: HealthRecordType.bowel,
      recordedAt: DateTime(2026, 10, 11, 9, 15),
      title: '배변 기록',
      summary: '복통',
      data: const {
        'bristol_type': 4,
        'pain': '심함',
        'urgency': '높음',
        'amount': '소량',
        'memo': '상세 메모',
      },
    );
    await repo.create(record);
    final router = await open(tester, repo);
    addTearDown(router.dispose);
    router.push('/records/detail', extra: record);
    await tester.pumpAndSettle();
    expect(find.text('2026.10.11 09:15'), findsOneWidget);
    expect(find.text('심함'), findsOneWidget);
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    final option = find.byKey(const ValueKey('bowel-form-5'));
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.tap(find.text('기록 저장하기'));
    await tester.pumpAndSettle();
    expect(find.text('부드러운 조각'), findsOneWidget);
    expect((await repo.list('demo-user')).single.recordedAt, record.recordedAt);
    expect(tester.takeException(), isNull);
  });
  testWidgets('좁은 화면과 큰 글씨에서도 인사이트 및 입력 화면이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = DemoRecordsRepository();
    await repo.create(
      meal('a', '라면', 'breakfast', 500).copyWith(recordedAt: DateTime.now()),
    );
    final router = await open(tester, repo, location: '/insights', scale: 1.6);
    addTearDown(router.dispose);
    expect(find.text('살펴봐요'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    router.go('/record/condition');
    await tester.pumpAndSettle();
    expect(find.text('어떤가요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '증상 기록'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    router.go('/record/visit');
    await tester.pumpAndSettle();
    expect(find.text('기록해요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    router.go('/calendar');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    router.go('/settings');
    await tester.pumpAndSettle();
    expect(find.text('기본 적용 안내'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('같은 날짜와 끼니만 합치고 열량을 합산한다', () {
    final groups = groupMeals([
      meal('a', '라면', 'breakfast', 500),
      meal('b', '삶은 계란', 'breakfast', 80, hour: 9),
      meal('c', '밥', 'lunch', 300, hour: 12),
      meal('d', '사과', 'snack', 90, hour: 15),
      meal('e', '빵', 'breakfast', 200, day: 10),
      meal('f', '우유', 'legacy', 120, hour: 16),
    ]);
    expect(groups.length, 5);
    final breakfast = groups.singleWhere(
      (g) => g.day.day == 11 && g.category == MealCategory.breakfast,
    );
    expect(breakfast.foods, '라면, 삶은 계란');
    expect(breakfast.calories, 580);
    expect(groups.first.category, MealCategory.breakfast);
    expect(
      groups.singleWhere((g) => g.category == MealCategory.snack).calories,
      90,
    );
  });

  testWidgets('그룹 열기, 음식별 열량, 아침 필터와 하단 홈 이동이 동작한다', (tester) async {
    final repository = DemoRecordsRepository();
    await repository.create(meal('a', '라면', 'breakfast', 500));
    await repository.create(meal('b', '삶은 계란', 'breakfast', 80, hour: 9));
    await repository.create(meal('c', '사과', 'snack', 90, hour: 15));
    final router = await open(tester, repository);
    addTearDown(router.dispose);
    expect(find.text('아침 - 라면, 삶은 계란'), findsOneWidget);
    expect(find.text('2026.10.11 · 총 580 kcal'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('아침 - 라면, 삶은 계란'));
    await tester.pumpAndSettle();
    expect(find.text('총 580 kcal'), findsOneWidget);
    expect(find.textContaining('500 kcal'), findsOneWidget);
    expect(find.text('09:00 ·  · 80 kcal'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '식사'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '아침'));
    await tester.pumpAndSettle();
    expect(find.text('아침 - 라면, 삶은 계란'), findsOneWidget);
    expect(find.text('간식 - 사과'), findsNothing);
    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    expect(find.text('홈 화면'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI 음식의 개별 열량은 섭취량에 맞춰 계산하고 수정 후 그룹도 갱신된다', (tester) async {
    final repository = DemoRecordsRepository();
    await repository.create(
      meal(
        'a',
        '라면, 계란',
        'breakfast',
        380,
        extra: {
          'items': [
            {
              'name': '라면',
              'amount_g': 150,
              'nutrition': {'base_amount_g': 100, 'energy_kcal': 200},
            },
            {
              'name': '계란',
              'amount_g': 50,
              'nutrition': {'base_amount_g': 100, 'energy_kcal': 160},
            },
          ],
        },
      ),
    );
    final router = await open(tester, repository);
    addTearDown(router.dispose);
    await tester.tap(find.text('아침 - 라면, 계란'));
    await tester.pumpAndSettle();
    expect(find.text('라면 · 150g · 300 kcal'), findsOneWidget);
    expect(find.text('계란 · 50g · 80 kcal'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '간식'));
    await tester.tap(find.text('기록 저장하기'));
    await tester.pumpAndSettle();
    expect(find.text('이 끼니에 등록된 음식이 없어요.'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('간식 - 라면, 계란'), findsOneWidget);
    expect(find.text('아침 - 라면, 계란'), findsNothing);
    expect(
      (await repository.list('demo-user')).single.data['meal_type'],
      'snack',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('좁은 화면에서도 간식을 선택해서 직접 기록할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = DemoRecordsRepository();
    final router = await open(tester, repository);
    addTearDown(router.dispose);
    router.push('/record/meal');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '간식'));
    await tester.enterText(find.byType(TextField).at(0), '견과류');
    await tester.enterText(find.byType(TextField).at(2), '120');
    await tester.tap(find.text('기록 저장하기'));
    await tester.pumpAndSettle();
    final saved = (await repository.list('demo-user')).single;
    expect(saved.data['meal_type'], 'snack');
    expect(saved.data['energy_kcal'], 120);
    expect(find.text('간식 - 견과류'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
