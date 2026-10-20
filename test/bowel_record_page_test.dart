import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:naazza/app/theme/app_theme.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/data/records_repository.dart';
import 'package:naazza/features/records/domain/health_record.dart';
import 'package:naazza/features/records/presentation/bowel_record_page.dart';
import 'package:naazza/features/records/presentation/bowel_form_selector.dart';

Future<GoRouter> openPage(
  WidgetTester tester,
  DemoRecordsRepository repository, {
  HealthRecord? record,
  double scale = 1,
}) async {
  final auth = DemoAuthRepository();
  await tester.runAsync(() => auth.signIn(username: 'tester', pin: '1234'));
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('기록 목록')),
      ),
      GoRoute(
        path: '/bowel',
        builder: (_, _) => BowelRecordPage(record: record),
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
        routerConfig: router,
        theme: AppTheme.light,
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
  router.push('/bowel');
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('중복 변비 스위치는 없고 배변 선택으로 돌아오면 변비가 해제된다', (tester) async {
    final repository = DemoRecordsRepository();
    final router = await openPage(tester, repository);
    addTearDown(router.dispose);
    expect(find.text('변비가 있었어요'), findsNothing);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '배변했어요'))
          .selected,
      true,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '변비 · 배변 못함'));
    await tester.pumpAndSettle();
    expect(find.byType(BowelFormSelector), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, '배변했어요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 저장하기'));
    await tester.pumpAndSettle();
    final saved = (await repository.list('demo-user')).single;
    expect(saved.data['had_bowel_movement'], true);
    expect(saved.data['constipation'], false);
    expect(saved.summary, isNot(contains('변비')));
  });
  testWidgets('배변 못함을 직접 선택한 경우에만 새 변비 기록이 저장된다', (tester) async {
    final repository = DemoRecordsRepository();
    final router = await openPage(tester, repository);
    addTearDown(router.dispose);
    await tester.tap(find.widgetWithText(ChoiceChip, '변비 · 배변 못함'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 저장하기'));
    await tester.pumpAndSettle();
    final saved = (await repository.list('demo-user')).single;
    expect(saved.data['had_bowel_movement'], false);
    expect(saved.data['constipation'], true);
    expect(saved.data['bristol_type'], isNull);
  });
  testWidgets('혈변 체크를 저장하고 다시 해제할 수 있다', (tester) async {
    final repository = DemoRecordsRepository();
    final router = await openPage(tester, repository);
    addTearDown(router.dispose);
    final toggle = find.byKey(const ValueKey('blood-in-stool'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 저장하기'));
    await tester.pumpAndSettle();
    final saved = (await repository.list('demo-user')).single;
    expect(saved.data['blood_in_stool'], true);
    expect(saved.summary, contains('혈변'));
    final editRouter = await openPage(tester, repository, record: saved);
    addTearDown(editRouter.dispose);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, true);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 저장하기'));
    await tester.pumpAndSettle();
    final edited = (await repository.list('demo-user')).single;
    expect(edited.data['blood_in_stool'], false);
    expect(edited.summary, isNot(contains('혈변')));
  });

  testWidgets('새 기록은 4번이 기본 선택되고 그대로 저장된다', (tester) async {
    final repository = DemoRecordsRepository();
    final router = await openPage(tester, repository);
    addTearDown(router.dispose);
    await tester.ensureVisible(find.byKey(const ValueKey('bowel-form-4')));
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.bySemanticsLabel('4번, 매끈하고 부드러움')),
      matchesSemantics(
        label: '4번, 매끈하고 부드러움',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
    await tester.tap(find.text('기록 저장하기'));
    await tester.pumpAndSettle();
    final saved = (await repository.list('demo-user')).single;
    expect(saved.data['bristol_type'], 4);
    expect(saved.summary, '매끈하고 부드러움 · 보통');
    expect(tester.takeException(), isNull);
  });

  testWidgets('설명을 보고 선택한 형태가 기존 1~7 값과 읽기 쉬운 요약으로 저장된다', (tester) async {
    final repository = DemoRecordsRepository();
    final router = await openPage(tester, repository);
    addTearDown(router.dispose);
    final option = find.byKey(const ValueKey('bowel-form-5'));
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(
      tester.widget<BowelFormSelector>(find.byType(BowelFormSelector)).value,
      5,
    );
    await tester.tap(find.text('기록 저장하기'));
    await tester.pumpAndSettle();
    final records = await repository.list('demo-user');
    expect(records, hasLength(1));
    expect(records.single.data['bristol_type'], 5);
    expect(records.single.summary, '부드러운 조각 · 보통');
    expect(find.text('기록 목록'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('이전 숫자 기록을 열고 수정해도 ID·시각·메모가 유지된다', (tester) async {
    final repository = DemoRecordsRepository();
    final recordedAt = DateTime(2026, 10, 10, 9);
    final record = HealthRecord(
      id: 'existing-bowel',
      userId: 'demo-user',
      type: HealthRecordType.bowel,
      recordedAt: recordedAt,
      title: '배변 기록',
      summary: 'Bristol 2 · 보통',
      data: const {'bristol_type': 2, 'memo': '기존 메모'},
    );
    await repository.create(record);
    final router = await openPage(tester, repository, record: record);
    addTearDown(router.dispose);
    expect(
      tester.widget<BowelFormSelector>(find.byType(BowelFormSelector)).value,
      2,
    );
    final option = find.byKey(const ValueKey('bowel-form-7'));
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 저장하기'));
    await tester.pumpAndSettle();
    final saved = (await repository.list('demo-user')).single;
    expect(saved.id, record.id);
    expect(saved.recordedAt, recordedAt);
    expect(saved.data['memo'], '기존 메모');
    expect(saved.data['blood_in_stool'], isNull);
    expect(saved.data['bristol_type'], 7);
    expect(saved.summary, '물처럼 묽음 · 보통');
    expect(tester.takeException(), isNull);
  });

  testWidgets('좁은 화면과 큰 글씨에서도 모든 형태를 읽고 선택할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = await openPage(tester, DemoRecordsRepository(), scale: 1.6);
    addTearDown(router.dispose);
    for (var type = 1; type <= 7; type++) {
      final option = find.byKey(ValueKey('bowel-form-$type'));
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(
        tester.widget<BowelFormSelector>(find.byType(BowelFormSelector)).value,
        type,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('짧은 선택 문구만 보이고 자세한 설명은 필요할 때 열 수 있다', (tester) async {
    final router = await openPage(tester, DemoRecordsRepository());
    addTearDown(router.dispose);
    expect(find.text('작고 단단한 조각이 따로 있어요'), findsNothing);
    expect(find.text('4 · 매끈하고 부드러움'), findsOneWidget);
    expect(find.byKey(const ValueKey('bowel-form-1')), findsOneWidget);
    final help = find.byKey(const ValueKey('bowel-form-help'));
    await tester.ensureVisible(help);
    await tester.pumpAndSettle();
    await tester.tap(help);
    await tester.pumpAndSettle();
    expect(find.text('작고 단단한 조각이 따로 있어요'), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('작고 단단한 조각이 따로 있어요'), findsNothing);
    expect(
      tester.widget<BowelFormSelector>(find.byType(BowelFormSelector)).value,
      4,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('그림 없이 설명을 표시하고 선택 상태를 접근성에 전달한다', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fontPath = Platform.environment['NAAZZA_PREVIEW_FONT'];
    if (fontPath != null) {
      final loader = FontLoader('PreviewKorean');
      loader.addFont(
        Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
      );
      await tester.runAsync(() => loader.load());
    }
    final materialFontPath =
        Platform.environment['NAAZZA_PREVIEW_MATERIAL_FONT'];
    if (materialFontPath != null) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(
        Future.value(
          ByteData.sublistView(File(materialFontPath).readAsBytesSync()),
        ),
      );
      await tester.runAsync(() => loader.load());
    }
    final semantics = tester.ensureSemantics();

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light.copyWith(
          textTheme: AppTheme.light.textTheme.apply(
            fontFamily: fontPath == null ? null : 'PreviewKorean',
          ),
        ),
        home: RepaintBoundary(
          key: boundaryKey,
          child: Scaffold(
            appBar: AppBar(title: const Text('배변 형태 안내')),
            body: const SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: BowelFormSelector(value: 4, onChanged: ignoreValue),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var type = 1; type <= 7; type++) {
      expect(find.byKey(ValueKey('bowel-form-$type')), findsOneWidget);
    }
    expect(find.textContaining('그림과 설명'), findsNothing);
    expect(find.byType(Image), findsNothing);
    final selected = find.bySemanticsLabel('4번, 매끈하고 부드러움');
    expect(
      tester.getSemantics(selected),
      matchesSemantics(
        label: '4번, 매끈하고 부드러움',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
    final output = Platform.environment['NAAZZA_WRITE_PREVIEW'];
    if (output != null) {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(output).parent.create(recursive: true);
        await File(output).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}

void ignoreValue(int value) {}
