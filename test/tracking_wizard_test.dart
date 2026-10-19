import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:naazza/app/theme/app_theme.dart';
import 'package:naazza/features/settings/presentation/accessibility_settings.dart';
import 'package:naazza/features/tracking_profile/domain/tracking_profile.dart';
import 'package:naazza/features/tracking_profile/presentation/tracking_profile_controller.dart';
import 'package:naazza/features/tracking_profile/presentation/tracking_profile_page.dart';

class TestProfileController extends TrackingProfileController {
  TestProfileController({this.initial, this.fail = false});
  final TrackingProfile? initial;
  bool fail;
  TrackingProfile? saved;
  @override
  Future<TrackingProfile?> build() async => initial;
  @override
  Future<void> save(TrackingProfile profile) async {
    saved = profile;
    state = fail
        ? AsyncError(Exception('offline'), StackTrace.current)
        : AsyncData(profile);
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    TestProfileController controller, {
    bool editing = false,
    bool reduce = false,
    double scale = 1,
    Size size = const Size(393, 852),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/setup',
      routes: [
        GoRoute(
          path: '/setup',
          builder: (_, _) => TrackingProfilePage(editing: editing),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('saved-home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackingProfileProvider.overrideWith(() => controller),
          reduceMotionProvider.overrideWith((ref) => reduce),
        ],
        child: RepaintBoundary(
          key: const ValueKey('tracking-preview'),
          child: MaterialApp.router(
            theme: Platform.environment['UPDATE_TRACKING_PREVIEW'] == '1'
                ? AppTheme.light.copyWith(
                    textTheme: AppTheme.light.textTheme.apply(
                      fontFamily: 'PreviewKorean',
                    ),
                  )
                : AppTheme.light,
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
  }

  Future<void> next(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tracking-next')));
    await tester.pumpAndSettle();
  }

  bool metric(WidgetTester tester, String key) =>
      tester.widget<SwitchListTile>(find.byKey(ValueKey('metric-$key'))).value;
  testWidgets(
    'both steps fit a small phone; selections and OFF choices survive goal changes and save',
    (tester) async {
      final controller = TestProfileController();
      await open(tester, controller, size: const Size(360, 640));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('tracking-next')))
            .onPressed,
        null,
      );
      expect(find.text('신장 컨디션 관리').hitTestable(), findsOneWidget);
      await tester.tap(find.text('장 컨디션 관리'));
      await next(tester);
      expect(metric(tester, 'fatigue'), true);
      await tester.tap(find.byKey(const ValueKey('metric-fatigue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tracking-reminders')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이전'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('장 컨디션 관리'));
      await tester.pump();
      await tester.tap(find.text('장 컨디션 관리'));
      await next(tester);
      expect(metric(tester, 'fatigue'), false);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('tracking-reminders')),
            )
            .value,
        false,
      );
      expect(
        find.byKey(const ValueKey('tracking-reminders')).hitTestable(),
        findsOneWidget,
      );
      await next(tester);
      expect(find.text('saved-home'), findsOneWidget);
      expect(controller.saved!.conditionKeys, ['ibd']);
      expect(
        controller.saved!.metrics
            .singleWhere((m) => m.metricKey == 'fatigue')
            .enabled,
        false,
      );
      expect(controller.saved!.remindersEnabled, false);
    },
  );
  testWidgets(
    'system back returns to goals; custom goals expose all metrics with reduced motion',
    (tester) async {
      await open(tester, TestProfileController(), reduce: true);
      await tester.tap(find.text('나만의 식습관 관리'));
      await next(tester);
      expect(
        find.byKey(const ValueKey('metric-blood_glucose')),
        findsOneWidget,
      );
      expect(metric(tester, 'blood_glucose'), false);
      await tester.tap(find.byKey(const ValueKey('metric-blood_glucose')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('어떤 목표로 기록할까요?'), findsOneWidget);
      await next(tester);
      expect(metric(tester, 'blood_glucose'), true);
      final tween = tester.widget<TweenAnimationBuilder<double>>(
        find.byType(TweenAnimationBuilder<double>),
      );
      expect(tween.duration, Duration.zero);
    },
  );
  testWidgets(
    'edit loads disabled metrics; failed save keeps choices and permits retry',
    (tester) async {
      final controller = TestProfileController(
        fail: true,
        initial: const TrackingProfile(
          conditionKeys: ['ibd'],
          metrics: [
            TrackingMetricSelection(
              metricKey: 'fatigue',
              enabled: false,
              quickLogOrder: 0,
            ),
          ],
          remindersEnabled: false,
        ),
      );
      await open(tester, controller, editing: true);
      await next(tester);
      expect(metric(tester, 'fatigue'), false);
      await next(tester);
      expect(find.textContaining('선택한 내용은 그대로'), findsOneWidget);
      expect(metric(tester, 'fatigue'), false);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('tracking-next')))
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets(
    'large text can scroll to metrics while footer stays accessible',
    (tester) async {
      await open(
        tester,
        TestProfileController(),
        scale: 2,
        size: const Size(360, 640),
      );
      await tester.tap(find.text('혈당 관리'));
      await next(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('tracking-reminders')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('tracking-next')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
    },
  );
  testWidgets('optional tracking wizard preview', (tester) async {
    if (Platform.environment['UPDATE_TRACKING_PREVIEW'] != '1') return;
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
    Future<void> capture(String name) async {
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
        find.byKey(const ValueKey('tracking-preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'artifacts/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await open(tester, TestProfileController());
    await tester.tap(find.text('혈당 관리'));
    await tester.tap(find.text('장 컨디션 관리'));
    await tester.tap(find.text('나만의 식습관 관리'));
    await tester.pumpAndSettle();
    await capture('tracking-goals-preview');
    await tester.pumpWidget(const SizedBox());
    await open(tester, TestProfileController());
    await tester.tap(find.text('장 컨디션 관리'));
    await tester.pumpAndSettle();
    await next(tester);
    await tester.tap(find.byKey(const ValueKey('metric-fatigue')));
    await tester.pumpAndSettle();
    await capture('tracking-metrics-preview');
  });
}
