import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naazza/app/theme/app_theme.dart';
import 'package:naazza/app/theme/app_design.dart';
import 'package:naazza/core/widgets/app_page.dart';
import 'package:naazza/core/widgets/word_wrap_text.dart';
import 'package:naazza/features/home/presentation/home_page.dart';
import 'package:naazza/features/records/presentation/records_calendar_page.dart';
import 'package:naazza/features/records/presentation/records_controller.dart';
import 'package:naazza/features/records/domain/health_record.dart';
import 'package:naazza/features/insights/presentation/insights_page.dart';
import 'package:naazza/features/settings/presentation/accessibility_settings.dart';
import 'package:naazza/features/tracking_profile/domain/tracking_profile.dart';
import 'package:naazza/features/tracking_profile/presentation/tracking_profile_controller.dart';

List<HealthRecord> sampleRecords() {
  final now = DateTime.now();
  return [
    for (var i = 0; i < 8; i++)
      for (final hour in [8, 18])
        HealthRecord(
          id: 'meal-$i-$hour',
          userId: 'demo',
          type: HealthRecordType.meal,
          recordedAt: DateTime(now.year, now.month, now.day - i, hour),
          title: hour == 8 ? '삶은 계란' : '채소 비빔밥',
          summary: '식사 기록',
          data: {
            'meal_type': hour == 8 ? 'breakfast' : 'dinner',
            'energy_kcal': hour == 8 ? 160 : 480,
            'items': [
              {
                'name': hour == 8 ? '삶은 계란' : '채소 비빔밥',
                'amount_g': 100,
                'nutrition': {
                  'base_amount_g': 100,
                  'protein_g': hour == 8 ? 12 : 23,
                  'calcium_mg': 160,
                  'iron_mg': 3,
                  'vitamin_c_mg': 20,
                  'fiber_g': 5,
                },
              },
            ],
          },
        ),
    HealthRecord(
      id: 'bowel',
      userId: 'demo',
      type: HealthRecordType.bowel,
      recordedAt: DateTime(now.year, now.month, now.day, 9),
      title: '배변 기록',
      summary: '양호',
      data: {'bristol_type': 4, 'had_bowel_movement': true},
    ),
    HealthRecord(
      id: 'condition',
      userId: 'demo',
      type: HealthRecordType.condition,
      recordedAt: DateTime(now.year, now.month, now.day - 1, 13),
      title: '컨디션 기록',
      summary: '평온해요',
      data: {
        'symptoms': ['복통'],
        'severity': 2,
        'response_status': 'symptom',
        'symptom_events': {
          '복통': {'phase': 'new', 'severity': 2},
        },
      },
    ),
  ];
}

class DesignRecords extends RecordsController {
  DesignRecords(this.items);
  final List<HealthRecord> items;
  @override
  Future<List<HealthRecord>> build() async => items;
}

class DesignProfile extends TrackingProfileController {
  @override
  Future<TrackingProfile?> build() async => const TrackingProfile(
    conditionKeys: ['ibd'],
    metrics: [
      TrackingMetricSelection(
        metricKey: 'bowel',
        enabled: true,
        quickLogOrder: 0,
      ),
      TrackingMetricSelection(
        metricKey: 'abdominal_pain',
        enabled: true,
        quickLogOrder: 1,
      ),
    ],
    remindersEnabled: true,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<GoRouter> open(
    WidgetTester tester, {
    double scale = 1,
    bool empty = false,
    bool preview = false,
  }) async {
    tester.view.physicalSize = preview
        ? const Size(393, 852)
        : const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomePage()),
        GoRoute(
          path: '/calendar',
          builder: (_, _) => const RecordsCalendarPage(),
        ),
        GoRoute(path: '/insights', builder: (_, _) => const InsightsPage()),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const AccessibilitySettingsPage(),
        ),
        GoRoute(
          path: '/record',
          builder: (_, _) => const Scaffold(body: Text('기록하기')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final auth = DemoAuthRepository();
    if (preview) {
      await tester.runAsync(() async {
        await auth.signIn(username: 'preview', pin: '1234');
        await auth.updateNutritionProfile(
          birthDate: DateTime(1990, 5, 12),
          sex: 'male',
        );
      });
    }
    final base = AppTheme.light;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          recordsProvider.overrideWith(
            () => DesignRecords(empty ? [] : sampleRecords()),
          ),
          trackingProfileProvider.overrideWith(DesignProfile.new),
        ],
        child: RepaintBoundary(
          key: const ValueKey('main-preview'),
          child: MaterialApp.router(
            theme: preview
                ? base.copyWith(
                    textTheme: base.textTheme.apply(
                      fontFamily: 'PreviewKorean',
                    ),
                  )
                : base,
            debugShowCheckedModeBanner: false,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('four tabs share headers and remain usable at scale $scale', (
      tester,
    ) async {
      final router = await open(tester, scale: scale);
      for (final path in ['/home', '/calendar', '/insights', '/settings']) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(find.byType(AppPage), findsOneWidget);
        final heading = find.descendant(
          of: find.byType(AppPageTitle),
          matching: find.byType(Text),
        );
        expect(tester.widget<Text>(heading).style, AppDesign.pageTitle);
        expect(tester.takeException(), null, reason: 'top of $path');
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -1800),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), null, reason: 'body of $path');
        expect(find.byType(NavigationBar).hitTestable(), findsOneWidget);
      }
    });
  }
  testWidgets('empty records and word boundary paragraphs stay readable', (
    tester,
  ) async {
    final router = await open(tester, empty: true, scale: 2);
    for (final path in ['/home', '/calendar', '/insights']) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SizedBox(
            width: 110,
            child: WordWrapText('오늘도 편안하게\n기록해요', style: AppDesign.body),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('오늘도'), findsOneWidget);
    expect(find.text('편안하게'), findsOneWidget);
    expect(find.text('기록해요'), findsOneWidget);
    expect(tester.takeException(), null);
  });
  testWidgets('optional four main pages preview', (tester) async {
    if (Platform.environment['UPDATE_MAIN_PREVIEW'] != '1') return;
    await tester.runAsync(() async {
      final font = await File('C:/Windows/Fonts/malgun.ttf').readAsBytes();
      await (FontLoader(
        'PreviewKorean',
      )..addFont(Future.value(ByteData.sublistView(font)))).load();
      final icons = await File(
        'C:/utils/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    });
    final router = await open(tester, preview: true);
    for (final entry in {
      'home': '/home',
      'calendar': '/calendar',
      'insights': '/insights',
      'more': '/settings',
    }.entries) {
      router.go(entry.value);
      await tester.pumpAndSettle();
      for (final element in find.byType(RichText).evaluate()) {
        final p = element.renderObject! as RenderParagraph;
        final span = p.text as TextSpan;
        if (span.style?.fontFamily == null) {
          p.text = TextSpan(
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
        find.byKey(const ValueKey('main-preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'artifacts/mint-${entry.key}-implemented.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
