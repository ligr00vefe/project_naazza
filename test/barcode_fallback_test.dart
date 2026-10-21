import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:naazza/app/theme/app_theme.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/meal_analysis/data/demo_meal_analysis_repository.dart';
import 'package:naazza/features/meal_analysis/data/meal_analysis_repository.dart';
import 'package:naazza/features/meal_analysis/domain/barcode_photo_fallback.dart';
import 'package:naazza/features/meal_analysis/domain/meal_analysis.dart';
import 'package:naazza/features/meal_analysis/presentation/barcode_scanner_page.dart';
import 'package:naazza/features/meal_analysis/presentation/meal_capture_page.dart';
import 'package:naazza/features/meal_analysis/presentation/public_product_dialog.dart';
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/data/records_repository.dart';
import 'package:naazza/features/records/domain/record_draft_date.dart';
import 'package:naazza/features/records/presentation/meal_record_page.dart';

class BarcodeFallbackSpy extends DemoMealAnalysisRepository {
  int scans = 0, analyses = 0;
  @override
  Future<FoodCandidate?> lookupBarcode(String barcode) async {
    scans++;
    expect(barcode, '8801056251154');
    return null;
  }

  @override
  Future<MealAnalysisResult> analyze({
    required String userId,
    required Uint8List imageBytes,
    required String filename,
  }) async {
    analyses++;
    return const MealAnalysisResult(
      photoPath: 'test/photo.png',
      foods: [],
      identifiedProducts: [
        IdentifiedProduct(name: '테스트 제로 라임', amountText: '1800ml'),
      ],
    );
  }
}

void main() {
  for (final (cancelCamera, publicFound) in [
    (false, true),
    (true, false),
    (false, false),
  ]) {
    testWidgets('바코드 미등록 → 사진 → 공공데이터 (촬영 취소: $cancelCamera, 후보: $publicFound)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final name in ['method', 'event', 'deviceOrientation']) {
        final channel = MethodChannel(
          'dev.steenbakker.mobile_scanner/scanner/$name',
        );
        messenger.setMockMethodCallHandler(channel, (_) async => null);
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      }
      final auth = DemoAuthRepository(),
          repo = BarcodeFallbackSpy(),
          records = DemoRecordsRepository();
      await tester.runAsync(() => auth.signIn(username: 'tester', pin: '1234'));
      var photos = 0, lookups = 0;
      final at = DateTime.now().subtract(const Duration(days: 1));
      final router = GoRouter(
        initialLocation: recordDateRoute('/barcode', at),
        routes: [
          GoRoute(
            path: '/barcode',
            builder: (_, s) => BarcodeScannerPage(
              initialRecordedAt: parseRecordDraftDate(
                s.uri.queryParameters['at'],
              ),
            ),
          ),
          GoRoute(
            path: '/record/meal-photo',
            builder: (_, s) {
              expect(
                (s.extra as BarcodePhotoFallback).barcode,
                '8801056251154',
              );
              expect(parseRecordDraftDate(s.uri.queryParameters['at']), at);
              return MealCapturePage(
                initialRecordedAt: parseRecordDraftDate(
                  s.uri.queryParameters['at'],
                ),
                barcodeFallback: s.extra as BarcodePhotoFallback,
                pickImage: (source) async {
                  photos++;
                  expect(source, ImageSource.camera);
                  if (cancelCamera) return null;
                  return XFile.fromData(
                    base64Decode(
                      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aO1sAAAAASUVORK5CYII=',
                    ),
                    name: 'product.png',
                  );
                },
                publicLookup: (query, page) async {
                  lookups++;
                  expect(query, '테스트 제로 라임');
                  if (!publicFound) {
                    return {'status': 'not_found', 'candidates': []};
                  }
                  return {
                    'status': 'candidates',
                    'candidates': [
                      {
                        'id': 'fixture',
                        'name': query,
                        'dataCode': 'P',
                        'basis': {'value': 100, 'unit': 'ml'},
                        'packageSize': {'value': 1800, 'unit': 'ml'},
                        'nutrition': {'energyKcal': 0},
                        'source': {'recordId': 'fixture'},
                      },
                    ],
                  };
                },
              );
            },
          ),
          GoRoute(path: '/timeline', builder: (_, _) => const Scaffold()),
          GoRoute(
            path: '/record/meal',
            builder: (_, s) {
              final photo = s.extra as ManualMealPhoto;
              expect(photo.bytes, isNotEmpty);
              expect(photo.productName, '테스트 제로 라임');
              expect(parseRecordDraftDate(s.uri.queryParameters['at']), at);
              return const Scaffold(body: Text('직접 입력 전환 완료'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            mealAnalysisRepositoryProvider.overrideWithValue(repo),
            recordsRepositoryProvider.overrideWithValue(records),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('조회처에 등록된 제품 정보만'), findsOneWidget);
      expect(find.textContaining('2018'), findsNothing);
      final manual = find.widgetWithText(TextField, '바코드 번호 직접 입력');
      await tester.scrollUntilVisible(
        manual,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(manual, '8801056251154');
      await tester.tap(
        find.descendant(
          of: manual,
          matching: find.byIcon(Icons.search_rounded),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.scans, 1);
      expect(find.byType(MobileScanner), findsNothing);
      final next = find.byKey(const ValueKey('barcode-photo-fallback'));
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(photos, 1);
      expect(repo.analyses, cancelCamera ? 0 : 1);
      expect(lookups, cancelCamera ? 0 : 1);
      expect(await records.list('demo-user'), isEmpty);
      if (cancelCamera) {
        expect(find.text('앨범 선택'), findsOneWidget);
      } else if (publicFound) {
        expect(find.byType(PublicProductDialog), findsOneWidget);
        // A candidate must never be silently saved as the scanned product.
        await tester.ensureVisible(find.text('현재 제품과 같아요'));
        await tester.tap(find.text('현재 제품과 같아요'));
        await tester.pumpAndSettle();
        expect(find.byType(PublicProductDialog), findsNothing);
        expect(lookups, 1);
      } else {
        expect(find.byType(PublicProductDialog), findsOneWidget);
        expect(find.textContaining('후보를 찾지 못했어요'), findsOneWidget);
        await tester.ensureVisible(find.text('사진 첨부해 직접 입력').last);
        await tester.tap(find.text('사진 첨부해 직접 입력').last);
        await tester.pumpAndSettle();
        expect(find.text('직접 입력 전환 완료'), findsOneWidget);
        expect(lookups, 1);
        expect(repo.analyses, 1);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
