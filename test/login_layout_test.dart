import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naazza/app/theme/app_theme.dart';
import 'package:naazza/core/config/app_config.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/auth/presentation/login_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> open(WidgetTester tester, Size size, {double scale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              supabaseUrl: 'https://test.supabase.co',
              supabasePublishableKey: 'test',
            ),
          ),
          authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
        ],
        child: RepaintBoundary(
          key: const ValueKey('preview'),
          child: MaterialApp(
            theme: Platform.environment['UPDATE_LOGIN_PREVIEW'] == '1'
                ? AppTheme.light.copyWith(
                    textTheme: AppTheme.light.textTheme.apply(
                      fontFamily: 'PreviewKorean',
                    ),
                  )
                : AppTheme.light,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const LoginPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(360, 640), const Size(393, 852)]) {
    testWidgets('login and signup fit without scrolling at $size', (
      tester,
    ) async {
      await open(tester, size);
      final button = find.byKey(const ValueKey('login-submit'));
      final mode = find.byKey(const ValueKey('login-mode'));
      expect(tester.getBottomRight(mode).dy, lessThanOrEqualTo(size.height));
      expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(size.height));
      expect(
        tester.getTopLeft(find.text('아이디 저장')).dy,
        tester.getTopLeft(find.text('자동 로그인')).dy,
      );
      final heading = tester.widget<Text>(
        find.byKey(const ValueKey('login-heading')),
      );
      expect(heading.maxLines, 1);
      expect(heading.softWrap, false);
      expect(heading.style!.fontSize, lessThanOrEqualTo(22));
      expect(find.byKey(const ValueKey('login-form-card')), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.tap(mode);
      await tester.pumpAndSettle();
      expect(find.text('나의 기록을 시작해요'), findsOneWidget);
      expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(size.height));
    });
  }
  testWidgets('large type and keyboard allow reaching login without overflow', (
    tester,
  ) async {
    await open(tester, const Size(360, 640), scale: 2);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('login-submit'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.takeException(), null);
  });
  testWidgets('optional actual Flutter login preview', (tester) async {
    if (Platform.environment['UPDATE_LOGIN_PREVIEW'] != '1') return;
    await tester.runAsync(() async {
      final bytes = await File('C:/Windows/Fonts/malgun.ttf').readAsBytes();
      final loader = FontLoader('PreviewKorean')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      final icons = await File(
        'C:/utils/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    });
    await open(tester, const Size(393, 852));
    // Widget tests use an Ahem fallback for styles without a font family.
    // Replace only that test fallback when exporting a readable Korean preview.
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
      find.byKey(const ValueKey('preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/login-design-b-preview.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}
