import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/data/records_repository.dart';
import 'package:naazza/features/records/domain/health_record.dart';
import 'package:naazza/features/records/domain/alcohol_record.dart';
import 'package:naazza/features/records/domain/meal_group.dart';
import 'package:naazza/features/records/presentation/alcohol_record_page.dart';
import 'package:naazza/features/records/presentation/records_calendar_page.dart';
import 'package:naazza/features/meal_analysis/presentation/food_search_dialog.dart';
import 'meal_timeline_test.dart' show meal, open;

void main() {
  for (final (width, scale) in [
    (320.0, 1.0),
    (390.0, 1.0),
    (390.0, 1.5),
    (320.0, 2.0),
  ]) {
    testWidgets('음주 선택값과 목록 전체 표시: 화면 $width, 글자 $scale', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = DemoRecordsRepository();
      final router = await open(
        tester,
        repo,
        location: '/record/alcohol',
        scale: scale,
      );
      addTearDown(router.dispose);
      final drink = find.byType(DropdownButtonFormField<String>).first;
      await tester.ensureVisible(drink);
      await tester.tap(drink);
      await tester.pumpAndSettle();
      await tester.tap(find.text('맥주').last);
      await tester.pumpAndSettle();
      final glass = find.byType(DropdownButtonFormField<String>).at(1);
      expect(tester.getSize(glass).width, greaterThan(width - 100));
      await tester.ensureVisible(glass);
      await tester.tap(glass);
      await tester.pumpAndSettle();
      // Every menu option, including the longest PET label, must remain readable.
      for (final label in drinkContainers('맥주')) {
        final text = label == '직접 입력'
            ? label
            : '$label (${glassSizes[label]} cc)';
        final option = find.text(text).last;
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(option);
        expect(paragraph.didExceedMaxLines, isFalse, reason: text);
        expect(paragraph.overflow, isNot(TextOverflow.ellipsis), reason: text);
        for (var i = 0; i < text.length; i++) {
          if (text[i].trim().isEmpty) continue;
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1),
          );
          expect(boxes, isNotEmpty);
          for (final box in boxes) {
            expect(
              box.right,
              lessThanOrEqualTo(paragraph.size.width + 0.1),
              reason: text,
            );
            expect(
              box.bottom,
              lessThanOrEqualTo(paragraph.size.height + 0.1),
              reason: text,
            );
          }
        }
      }
      final longest = find.text('맥주 페트 1.6L (1600 cc)').last;
      await tester.ensureVisible(longest);
      await tester.tap(longest);
      await tester.pumpAndSettle();
      expect(find.text('맥주 페트 1.6L (1600 cc)'), findsOneWidget);
      final count = find.byKey(const ValueKey('count-0'));
      await tester.ensureVisible(count);
      await tester.enterText(count, '2');
      await tester.tap(find.text('기록 저장하기'));
      await tester.pumpAndSettle();
      final saved = (await repo.list('demo-user')).single;
      expect(saved.data['total_ml'], 3200);
      expect((saved.data['items'] as List).single['glass_label'], '맥주 페트 1.6L');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('기존 와인잔 용량은 옵션 통합 후에도 보존되고 추가 주종을 삭제할 수 있다', (tester) async {
    final repo = DemoRecordsRepository();
    final old = HealthRecord(
      id: 'old-wine',
      userId: 'demo-user',
      type: HealthRecordType.alcohol,
      recordedAt: DateTime.now(),
      title: '와인',
      summary: '1.5잔',
      data: const {
        'drink_type': '와인',
        'servings': 1.5,
        'glass_label': '와인잔 125',
        'glass_ml': 125,
        'total_ml': 187.5,
      },
    );
    await repo.create(old);
    final router = await open(
      tester,
      repo,
      location: '/record/alcohol',
      initialRecord: old,
    );
    addTearDown(router.dispose);
    expect(find.text('직접 입력'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('custom-0')))
          .controller
          ?.text,
      '125',
    );
    await tester.scrollUntilVisible(
      find.text('주종 추가'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('주종 추가'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('주종 삭제').last);
    await tester.tap(find.byTooltip('주종 삭제').last);
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    await tester.tap(find.text('기록 저장하기'));
    await tester.pumpAndSettle();
    final updated = (await repo.list('demo-user')).single;
    expect(updated.id, 'old-wine');
    expect(updated.data['total_ml'], 187.5);
    expect(tester.takeException(), isNull);
  });

  test('문자열 열량과 총합이 누락된 과거 음식의 섭취량을 합산한다', () {
    final records = [
      meal('a', '밥', 'breakfast', 0, extra: {'energy_kcal': '300.5'}),
      meal(
        'b',
        '계란',
        'breakfast',
        0,
        extra: {
          'items': [
            {
              'name': '계란',
              'amount_g': '50',
              'nutrition': {'base_amount_g': '100', 'energy_kcal': '155'},
            },
          ],
        },
      ),
    ];
    expect(groupMeals(records).single.calories, 378);
    final groups = groupMealSessions([
      meal('d', '저녁', 'dinner', 100, hour: 7),
      meal('l', '점심', 'lunch', 100, hour: 10),
      ...records,
    ])..sort(compareMealGroups);
    expect(groups.map((g) => g.category), [
      MealCategory.breakfast,
      MealCategory.lunch,
      MealCategory.dinner,
    ]);
  });
  testWidgets('검색 없이 이름만 추가하는 선택을 반환한다', (tester) async {
    FoodSearchRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<FoodSearchRequest>(
                  context: context,
                  builder: (_) => const FoodSearchDialog(),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '집밥');
    await tester.tap(find.text('이름만 추가'));
    await tester.pumpAndSettle();
    expect(result?.name, '집밥');
    expect(result?.search, false);
    expect(tester.takeException(), isNull);
  });
  testWidgets('맥주 2.5잔과 소주 한 병을 한 기록으로 저장하고 달력에 표시한다', (tester) async {
    final repo = DemoRecordsRepository(), auth = DemoAuthRepository();
    await tester.runAsync(() => auth.signIn(username: 'tester', pin: '1234'));
    final router = GoRouter(
      initialLocation: '/record/alcohol',
      routes: [
        GoRoute(
          path: '/record/alcohol',
          builder: (_, _) => const AlcoholRecordPage(),
        ),
        GoRoute(
          path: '/calendar',
          builder: (_, _) => const RecordsCalendarPage(),
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
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('맥주').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('count-0')));
    await tester.enterText(find.byKey(const ValueKey('count-0')), '2.5');
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<String>).at(1),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('맥주컵 300 (300 cc)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('맥주컵 300 (300 cc)'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('주종 추가'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('주종 추가'));
    await tester.pumpAndSettle();
    final lastContainer = find.byKey(const ValueKey('glass-1-소주-소주잔'));
    await tester.scrollUntilVisible(
      lastContainer,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(lastContainer);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('소주병 (360 cc)'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('소주병 (360 cc)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 저장하기'));
    await tester.pumpAndSettle();
    final saved = (await repo.list('demo-user')).single;
    expect(saved.type, HealthRecordType.alcohol);
    expect(saved.data['total_ml'], 1110);
    expect((saved.data['items'] as List).length, 2);
    expect(saved.title, '맥주, 소주');
    router.go('/calendar');
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('alcohol-marker-${DateTime.now().day}')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
