import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/app/theme/app_theme.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/data/records_repository.dart';
import 'package:naazza/features/records/domain/health_record.dart';
import 'package:naazza/features/records/presentation/records_controller.dart';
import 'package:naazza/features/insights/domain/nutrient_intake.dart';
import 'package:naazza/features/insights/presentation/nutrient_insight_card.dart';
import 'package:naazza/features/insights/presentation/hydration_banner.dart';
import 'package:naazza/core/widgets/word_wrap_text.dart';

void main() {
  testWidgets(
    'hydration banner shows only daily cups with illustration and no tracking controls at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const Scaffold(
              body: SingleChildScrollView(child: HydrationBanner()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is WordWrapText && w.text == '하루 물 5~7컵 마시',
        ),
        findsOneWidget,
      );
      expect(find.byType(WordWrapText), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'confirmed nutrients complete a day, persist, and appear in monthly counts at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = DemoAuthRepository(), repo = DemoRecordsRepository();
      await tester.runAsync(() => auth.signIn(username: 'tester', pin: '1234'));
      await auth.updateNutritionProfile(
        birthDate: DateTime(1990),
        sex: 'male',
        lifeStage: 'general',
      );
      final now = DateTime.now();
      await repo.create(
        HealthRecord(
          id: 'meal',
          userId: 'demo-user',
          type: HealthRecordType.meal,
          recordedAt: now,
          title: '테스트 식사',
          summary: '',
          data: {
            'items': [
              {
                'amount': 1000,
                'amount_unit': 'ml',
                'nutrition_source': {
                  'basis': {'value': 100, 'unit': 'ml'},
                  'nutrition': {'calciumMg': 80, 'proteinG': 5},
                },
              },
            ],
          },
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            recordsRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ref
                    .watch(recordsProvider)
                    .when(
                      loading: () => const CircularProgressIndicator(),
                      error: (e, s) => Text('$e'),
                      data: (records) => SingleChildScrollView(
                        child: NutrientInsightCard(records: records),
                      ),
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('nutrient-status-calcium')))
            .data,
        '100% 기록',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('nutrition-day-complete')),
      );
      await tester.tap(find.byKey(const ValueKey('nutrition-day-complete')));
      await tester.pumpAndSettle();
      final saved = await repo.list('demo-user');
      expect(NutrientDay.fromRecords(saved, now).complete, true);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('nutrient-status-calcium')))
            .data,
        '충족',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('extra-nutrients')));
      await tester.tap(find.byKey(const ValueKey('extra-nutrients')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('nutrient-status-vitaminA')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('nutrient-status-niacin')))
            .data,
        '정보 없음',
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '월별'));
      await tester.tap(find.widgetWithText(ChoiceChip, '월별'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('nutrient-status-calcium')))
            .data,
        '1 / 1일 충족',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('optional real Flutter nutrient preview', (tester) async {
    if (Platform.environment['UPDATE_NUTRIENT_PREVIEW'] != '1') return;
    tester.view.physicalSize = const Size(393, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final bytes = await File('C:/Windows/Fonts/malgun.ttf').readAsBytes();
      await (FontLoader(
        'PreviewKorean',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    });
    final auth = DemoAuthRepository();
    await tester.runAsync(() => auth.signIn(username: 'tester', pin: '1234'));
    await auth.updateNutritionProfile(
      birthDate: DateTime(1990),
      sex: 'male',
      lifeStage: 'general',
    );
    final now = DateTime.now();
    final meal = HealthRecord(
      id: 'example',
      userId: 'demo-user',
      type: HealthRecordType.meal,
      recordedAt: now,
      title: '디자인 확인용 예시 식사',
      summary: '',
      data: {
        'items': [
          {
            'amount': 100,
            'amount_unit': 'g',
            'nutrition': {
              'base_amount': 100,
              'amount_unit': 'g',
              'protein_g': 58.5,
              'calcium_mg': 480,
              'iron_mg': 8,
              'vitamin_c_mg': 100,
              'fiber_g': 21.6,
            },
          },
        ],
      },
    );
    final records = [
      meal.copyWith(
        data: {
          ...meal.data,
          'nutrition_day_signature': NutrientDay.fromRecords([
            meal,
          ], now).signature,
        },
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: MaterialApp(
          theme: AppTheme.light.copyWith(
            textTheme: AppTheme.light.textTheme.apply(
              fontFamily: 'PreviewKorean',
            ),
          ),
          home: RepaintBoundary(
            key: const ValueKey('nutrient-preview'),
            child: Scaffold(
              appBar: AppBar(title: const Text('인사이트 · 예시 기록')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: NutrientInsightCard(records: records),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final element in find.byType(RichText).evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      final span = paragraph.text as TextSpan;
      if (span.style?.fontFamily == null) {
        paragraph.text = TextSpan(
          text: span.text,
          children: span.children,
          style: (span.style ?? const TextStyle()).copyWith(
            fontFamily: 'PreviewKorean',
          ),
        );
      }
    }
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('nutrient-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/nutrient-insight-v33-preview.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });
  testWidgets('optional hydration banner preview', (tester) async {
    if (Platform.environment['UPDATE_NUTRIENT_PREVIEW'] != '1') return;
    tester.view.physicalSize = const Size(393, 380);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final bytes = await File('C:/Windows/Fonts/malgun.ttf').readAsBytes();
      await (FontLoader(
        'PreviewKorean',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light.copyWith(
          textTheme: AppTheme.light.textTheme.apply(
            fontFamily: 'PreviewKorean',
          ),
        ),
        home: RepaintBoundary(
          key: const ValueKey('hydration-preview'),
          child: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: HydrationBanner(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final element in find.byType(RichText).evaluate()) {
      final p = element.renderObject! as RenderParagraph;
      final s = p.text as TextSpan;
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
      find.byKey(const ValueKey('hydration-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/hydration-banner-preview.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
