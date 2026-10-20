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
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/auth/presentation/personal_info_page.dart';
import 'package:naazza/features/export/presentation/export_page.dart';
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/data/records_repository.dart';
import 'package:naazza/features/records/presentation/alcohol_record_page.dart';
import 'package:naazza/features/records/presentation/bowel_record_page.dart';
import 'package:naazza/features/records/presentation/condition_record_page.dart';
import 'package:naazza/features/records/presentation/meal_record_page.dart';
import 'package:naazza/features/records/presentation/record_hub_page.dart';
import 'package:naazza/features/records/presentation/water_record_page.dart';
import 'package:naazza/features/visits/presentation/visit_record_page.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'mint input flows scroll with accessible save actions at $scale',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final preview = Platform.environment['UPDATE_MINT_FLOW_PREVIEW'] == '1';
        tester.view.physicalSize = preview
            ? const Size(393, 852)
            : const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = DemoAuthRepository();
        await tester.runAsync(() async {
          await auth.signIn(username: 'preview', pin: '1234');
          if (preview) {
            for (final font in [
              ('PreviewKorean', 'C:/Windows/Fonts/malgun.ttf'),
              (
                'MaterialIcons',
                'C:/utils/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ),
            ]) {
              final bytes = await File(font.$2).readAsBytes();
              await (FontLoader(
                font.$1,
              )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
            }
          }
        });
        final pages = <String, Widget>{
          'hub': const RecordHubPage(),
          'meal': const MealRecordPage(),
          'bowel': const BowelRecordPage(),
          'condition': const ConditionRecordPage(),
          'alcohol': const AlcoholRecordPage(),
          'visit': const VisitRecordPage(),
          'water': const WaterRecordPage(),
          'personal': const PersonalInfoPage(),
          'export': const ExportPage(),
        };
        final router = GoRouter(
          initialLocation: '/hub',
          routes: [
            for (final page in pages.entries)
              GoRoute(path: '/${page.key}', builder: (_, _) => page.value),
          ],
        );
        addTearDown(router.dispose);
        final theme = AppTheme.light;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(auth),
              recordsRepositoryProvider.overrideWithValue(
                DemoRecordsRepository(),
              ),
            ],
            child: RepaintBoundary(
              key: const ValueKey('mint-flow'),
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: preview
                    ? theme.copyWith(
                        textTheme: theme.textTheme.apply(
                          fontFamily: 'PreviewKorean',
                        ),
                      )
                    : theme,
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
        for (final page in pages.keys) {
          router.go('/$page');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$page top / $scale');
          if (preview && scale == 1) {
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
              find.byKey(const ValueKey('mint-flow')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                'artifacts/mint-$page-implemented.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          final scroll = find.byType(Scrollable).first;
          await tester.drag(scroll, const Offset(0, -2400));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$page bottom / $scale',
          );
          if (page != 'hub' && page != 'export') {
            expect(
              find.byType(FilledButton).hitTestable(),
              findsWidgets,
              reason: '$page save stays accessible',
            );
          }
        }
      },
    );
  }
}
