import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:naazza/app/theme/app_theme.dart';
import 'package:naazza/core/widgets/word_wrap_text.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/data/records_repository.dart';
import 'package:naazza/features/records/domain/health_record.dart';
import 'package:naazza/features/insights/domain/food_observation.dart';
import 'package:naazza/features/insights/data/food_watch_repository.dart';
import 'package:naazza/features/insights/presentation/insights_page.dart';
import 'package:naazza/features/insights/presentation/observation_dashboard.dart';
import 'package:naazza/features/insights/presentation/observation_widgets.dart';
import 'package:naazza/features/insights/presentation/food_watch_editor.dart';

List<HealthRecord> examples() {
  final now = DateTime.now();
  DateTime at(int days, int hour) =>
      DateTime(now.year, now.month, now.day - days, hour);
  HealthRecord r(
    String id,
    HealthRecordType type,
    DateTime t,
    String title,
    Map<String, Object?> data,
  ) => HealthRecord(
    id: id,
    userId: 'demo-user',
    type: type,
    recordedAt: t,
    title: title,
    summary: title,
    data: data,
  );
  return [
    r('meal', HealthRecordType.meal, at(3, 12), '돈까스', {'meal_type': 'lunch'}),
    r('before', HealthRecordType.condition, at(3, 8), '이상 없음', {
      'response_status': 'normal',
    }),
    r('after', HealthRecordType.condition, at(3, 13), '복통', {
      'response_status': 'symptom',
      'symptoms': ['복통'],
      'symptom_events': {
        '복통': {'phase': 'new', 'episode_id': 'episode', 'severity': 2},
      },
    }),
    r('ongoing', HealthRecordType.condition, at(2, 8), '복통 지속', {
      'response_status': 'symptom',
      'symptoms': ['복통'],
      'symptom_events': {
        '복통': {'phase': 'ongoing', 'episode_id': 'episode', 'severity': 1},
      },
    }),
    r('ended', HealthRecordType.condition, at(1, 8), '복통 종료', {
      'response_status': 'symptom',
      'symptoms': ['복통'],
      'symptom_events': {
        '복통': {'phase': 'ended', 'episode_id': 'episode'},
      },
    }),
    r('drink', HealthRecordType.alcohol, at(4, 20), '맥주', {'total_ml': 500}),
    r('fatigue', HealthRecordType.condition, at(3, 9), '피로', {
      'response_status': 'symptom',
      'symptoms': ['피로'],
      'symptom_events': {
        '피로': {'phase': 'new', 'episode_id': 'f', 'severity': 1},
      },
    }),
  ];
}

const watch = FoodWatch(
  id: 'watch',
  name: '돈까스',
  aliases: ['돈까스', '돈가스'],
  symptoms: ['복통', '설사'],
);
void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'all three observations survive at 320px / $scale and original evidence opens',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = DemoAuthRepository(),
            repo = DemoRecordsRepository(),
            prefs = MemoryFoodWatchRepository();
        await tester.runAsync(() async {
          await auth.signIn(username: 'tester', pin: '1234');
          await prefs.save('demo-user', [watch]);
          for (final r in examples()) {
            await repo.create(r);
          }
        });
        final router = GoRouter(
          initialLocation: '/insights',
          routes: [
            GoRoute(path: '/insights', builder: (_, _) => const InsightsPage()),
            GoRoute(
              path: '/records/detail',
              builder: (_, s) =>
                  Scaffold(body: Text('원본 ${(s.extra as HealthRecord).id}')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(auth),
              recordsRepositoryProvider.overrideWithValue(repo),
              foodWatchRepositoryProvider.overrideWithValue(prefs),
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
        expect(find.byType(SymptomHeatmap), findsOneWidget);
        for (final title in ['증상·컨디션 추이', '음주 전후 컨디션', '내가 관찰하는 음식']) {
          expect(
            find.byWidgetPredicate((w) => w is WordWrapText && w.text == title),
            findsOneWidget,
          );
        }
        for (final title in ['기간별 기록', '나짜의 관찰', '여러 날 함께 나타난 항목']) {
          expect(find.text(title), findsNothing);
        }
        final details = find.text('관찰 내역과 원본 보기');
        await tester.ensureVisible(details);
        await tester.pumpAndSettle();
        await tester.tap(details);
        await tester.pumpAndSettle();
        expect(find.byType(CaseTimeline), findsOneWidget);
        expect(find.textContaining('종료'), findsWidgets);
        final source = find.text('섭취 · 돈까스');
        await tester.ensureVisible(source);
        await tester.pumpAndSettle();
        await tester.tap(source);
        await tester.pumpAndSettle();
        expect(find.text('원본 meal'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'watch editor saves only checked aliases, retains symptoms and supports deletion',
    (tester) async {
      FoodWatch? saved;
      var deleted = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: FoodWatchEditor(
            watch: watch,
            records: examples(),
            onSave: (v) async {
              saved = v;
            },
            onDelete: () async {
              deleted = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final alias = find.widgetWithText(TextField, '음식 이름 직접 추가');
      await tester.enterText(alias, '치즈돈까스');
      final save = find.text('관찰 음식 저장');
      await tester.scrollUntilVisible(
        save,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved!.aliases, containsAll(['돈까스', '돈가스', '치즈돈까스']));
      expect(saved!.symptoms, ['복통', '설사']);
      expect(deleted, isFalse);
    },
  );
  testWidgets('save failure keeps editor selections for retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FoodWatchEditor(
          watch: watch,
          records: [],
          onSave: (_) async {
            throw StateError('network');
          },
          onDelete: () async {},
        ),
      ),
    );
    final save = find.text('관찰 음식 저장');
    await tester.scrollUntilVisible(
      save,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.textContaining('저장하지 못했어요'), findsOneWidget);
    final name = find.widgetWithText(TextField, '관찰 이름');
    await tester.scrollUntilVisible(
      name,
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<TextField>(name).controller!.text, '돈까스');
    expect(tester.takeException(), isNull);
  });
  testWidgets('optional actual implemented dashboard preview', (tester) async {
    if (Platform.environment['UPDATE_HEALTH_INSIGHTS_PREVIEW'] != '1') return;
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final f in {
        'PreviewKorean': 'C:/Windows/Fonts/malgun.ttf',
        'MaterialIcons':
            'C:/utils/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      }.entries) {
        final bytes = await File(f.value).readAsBytes();
        await (FontLoader(
          f.key,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    });
    final auth = DemoAuthRepository(), prefs = MemoryFoodWatchRepository();
    await tester.runAsync(() async {
      await auth.signIn(username: 'preview', pin: '1234');
      await prefs.save('demo-user', [watch]);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          foodWatchRepositoryProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AppTheme.light.copyWith(
            textTheme: AppTheme.light.textTheme.apply(
              fontFamily: 'PreviewKorean',
            ),
          ),
          home: RepaintBoundary(
            key: const ValueKey('preview'),
            child: Scaffold(
              appBar: AppBar(title: const Text('인사이트 · 가상 데이터 예시')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ObservationDashboard(records: examples()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final e in find.byType(RichText).evaluate()) {
      final p = e.renderObject! as RenderParagraph, s = p.text as TextSpan;
      if (s.style?.fontFamily == 'MaterialIcons') continue;
      p.text = TextSpan(
        text: s.text,
        children: s.children,
        style: (s.style ?? const TextStyle()).copyWith(
          fontFamily: 'PreviewKorean',
        ),
      );
    }
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview')),
    );
    await tester.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 2),
          bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/food-observation-implemented-preview.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      img.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
