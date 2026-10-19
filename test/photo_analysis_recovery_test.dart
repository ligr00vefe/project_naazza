import 'package:naazza/features/meal_analysis/presentation/public_product_dialog.dart';
import 'package:naazza/features/records/domain/health_record.dart';
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/data/records_repository.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/meal_analysis/data/meal_analysis_repository.dart';
import 'package:naazza/features/meal_analysis/data/demo_meal_analysis_repository.dart';
import 'package:naazza/features/meal_analysis/domain/meal_analysis.dart';
import 'package:naazza/features/meal_analysis/domain/photo_failure.dart';
import 'package:naazza/features/meal_analysis/presentation/meal_capture_page.dart';
import 'package:naazza/features/records/presentation/meal_record_page.dart';

class RecoverySpy extends DemoMealAnalysisRepository {
  RecoverySpy(this.reason);
  final PhotoFailure reason;
  int requests = 0;
  Completer<MealAnalysisResult>? pending;
  final discarded = <String?>[];
  @override
  Future<MealAnalysisResult> analyze({
    required String userId,
    required Uint8List imageBytes,
    required String filename,
  }) {
    requests++;
    final next = pending;
    pending = null;
    return next?.future ?? Future.error(PhotoAnalysisException(reason));
  }

  @override
  Future<void> discardPhoto(String? path) async {
    if (path != null) discarded.add(path);
  }
}

final photoBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aO1sAAAAASUVORK5CYII=',
);

Future<GoRouter> openCapture(
  WidgetTester tester,
  RecoverySpy repo, {
  void Function(ManualMealPhoto)? onManual,
  DemoRecordsRepository? records,
  bool autoLookup = false,
  PublicProductLookup? publicLookup,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final auth = DemoAuthRepository();
  await tester.runAsync(() => auth.signIn(username: 'tester', pin: '1234'));
  final router = GoRouter(
    initialLocation: '/capture',
    routes: [
      GoRoute(
        path: '/capture',
        builder: (_, _) => MealCapturePage(
          autoLookup: autoLookup,
          publicLookup: publicLookup,
          pickImage: (_) async =>
              XFile.fromData(photoBytes, name: 'meal.png', path: 'meal.png'),
        ),
      ),
      GoRoute(path: '/blank', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/timeline',
        builder: (_, _) => const Scaffold(body: Text('저장 완료')),
      ),
      GoRoute(
        path: '/record/meal',
        builder: (_, state) {
          final photo = state.extra as ManualMealPhoto;
          onManual?.call(photo);
          return MealRecordPage(initialPhoto: photo);
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        recordsRepositoryProvider.overrideWithValue(
          records ?? DemoRecordsRepository(),
        ),
        mealAnalysisRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.tap(find.text('사진 촬영'));
  await tester.pump();
  await tester.pump();
  return router;
}

Future<void> tapAction(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pump();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'one recognized product automatically looks up once and still requires confirmation',
    (tester) async {
      final repo = RecoverySpy(PhotoFailure.missingNutrition);
      final result = Completer<MealAnalysisResult>();
      repo.pending = result;
      var lookups = 0;
      await openCapture(
        tester,
        repo,
        autoLookup: true,
        publicLookup: (query, page) async {
          lookups++;
          expect(query, '뉴케어 당플랜 호두맛');
          return {
            'status': 'candidates',
            'candidates': [
              {
                'id': 'fixture',
                'name': query,
                'dataCode': 'P',
                'basis': {'value': 100, 'unit': 'ml'},
                'packageSize': {'value': 200, 'unit': 'ml'},
                'nutrition': {'energyKcal': 100},
                'source': {'recordId': 'fixture'},
              },
            ],
          };
        },
      );
      result.complete(
        const MealAnalysisResult(
          photoPath: 'demo-user/front.png',
          foods: [],
          identifiedProducts: [
            IdentifiedProduct(
              name: '뉴케어 당플랜 호두맛',
              amountText: '200ml',
              energyKcal: 200,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(lookups, 1);
      expect(find.text('영양정보 확인'), findsOneWidget);
      await tester.ensureVisible(find.text('현재 제품과 같아요'));
      await tester.tap(find.text('현재 제품과 같아요'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('200 kcal'), 250, scrollable:find.byType(Scrollable).first);
      expect(find.text('200 kcal'), findsOneWidget);
      expect(lookups, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('뉴케어: 영양표 없이 200ml 200kcal가 자동 등록되고 수량·소분·저장까지 계산된다', (
    tester,
  ) async {
    final repo = RecoverySpy(PhotoFailure.missingNutrition),
        records = DemoRecordsRepository();
    final result = Completer<MealAnalysisResult>();
    repo.pending = result;
    await openCapture(tester, repo, records: records);
    result.complete(
      const MealAnalysisResult(
        photoPath: 'demo-user/front.png',
        foods: [],
        identifiedProducts: [
          IdentifiedProduct(
            name: '뉴케어 당플랜 호두맛',
            amountText: '200ml',
            energyKcal: 200,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('인식된 음식 1'), findsOneWidget);
    expect(find.text('확인한 정보로 기록하기'), findsNothing);
    expect(find.text('200 kcal'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('개수 늘리기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('개수 늘리기'));
    await tester.pumpAndSettle();
    expect(find.text('400 kcal'), findsOneWidget);
    await tapAction(tester, '소분해서 먹었어요');
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].decoration?.suffixText, 'ml');
    expect(fields[2].decoration?.suffixText, 'ml');
    await tester.enterText(find.byType(TextField).at(2), '100');
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(find.text('200 kcal'), findsOneWidget);
    await tester.tap(find.text('식사 저장'));
    await tester.pumpAndSettle();
    final record = (await records.list('demo-user')).single;
    expect(record.data['energy_kcal'], 200);
    final item = (record.data['items'] as List).single as Map;
    expect(item['amount_unit'], 'ml');
    expect(item['amount'], 200);
    expect(item['amount_g'], isNull);
    expect(item['quantity'], 2);
    expect(item['macronutrients_known'], false);
    expect((item['nutrition'] as Map)['protein_g'], isNull);
    expect(find.text('저장 완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('퀴노아 크래커: 같은 이름의 이전 기록이 있어도 열량·용량을 재사용하지 않는다', (tester) async {
    final repo = RecoverySpy(PhotoFailure.missingNutrition),
        records = DemoRecordsRepository();
    await records.create(
      HealthRecord(
        id: 'old',
        userId: 'demo-user',
        type: HealthRecordType.meal,
        recordedAt: DateTime(2026, 10, 7),
        title: '퀴노아 크래커',
        summary: '',
        data: {
          'items': [
            {
              'name': '퀴노아 크래커',
              'amount_g': 10,
              'nutrition': {'base_amount_g': 100, 'energy_kcal': 400},
            },
          ],
        },
      ),
    );
    final result = Completer<MealAnalysisResult>();
    repo.pending = result;
    await openCapture(tester, repo, records: records);
    await tester.pump();
    result.complete(
      const MealAnalysisResult(
        photoPath: 'demo-user/front.png',
        foods: [],
        identifiedProducts: [IdentifiedProduct(name: '퀴노아 크래커')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('40 kcal'), findsNothing);
    expect(find.textContaining('이전 기록 기준'), findsNothing);
    expect(find.text('확인한 정보로 기록하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final product in [const IdentifiedProduct(name: '퀴노아 크래커')]) {
    testWidgets(
      '${product.name}: front-label recognition fills only confirmed fields',
      (tester) async {
        final repo = RecoverySpy(PhotoFailure.missingNutrition);
        final result = Completer<MealAnalysisResult>();
        repo.pending = result;
        ManualMealPhoto? received;
        await openCapture(tester, repo, onManual: (photo) => received = photo);
        result.complete(
          MealAnalysisResult(
            photoPath: 'test/front.png',
            foods: const [],
            identifiedProducts: [product],
            failure: PhotoFailure.missingNutrition,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('제품명을 확인했어요'), findsOneWidget);
        expect(find.text(product.name), findsOneWidget);
        expect(find.text(PhotoFailure.missingNutrition.message), findsNothing);
        await tapAction(tester, '확인한 정보로 기록하기');
        final fields = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList();
        expect(fields[0].controller!.text, product.name);
        expect(
          fields[1].controller!.text,
          product.amountText.isEmpty ? '1개' : product.amountText,
        );
        expect(double.tryParse(fields[2].controller!.text), product.energyKcal);
        expect(received?.bytes, photoBytes);
        expect(repo.requests, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'four failures allow user retries without automatic retries or lockout',
    (tester) async {
      final repo = RecoverySpy(PhotoFailure.timeout);
      ManualMealPhoto? received;
      await openCapture(tester, repo, onManual: (photo) => received = photo);
      await tester.pumpAndSettle();
      for (var count = 1; count <= 4; count++) {
        expect(repo.requests, count);
        expect(find.text('다시 분석'), findsOneWidget);
        expect(find.text('재촬영하기'), findsOneWidget);
        expect(find.text('다른 사진 선택'), findsOneWidget);
        await tester.pump(const Duration(seconds: 35));
        expect(repo.requests, count);
        expect(find.textContaining('5분'), findsNothing);
        if (count < 4) await tapAction(tester, '다시 분석');
      }
      expect(find.widgetWithText(FilledButton, '사진 첨부해 직접 입력'), findsOneWidget);
      await tapAction(tester, '사진 첨부해 직접 입력');
      expect(received?.bytes, photoBytes);
      expect(received?.filename, 'meal.png');
      expect(repo.requests, 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final reason in [
    PhotoFailure.blurry,
    PhotoFailure.productUnidentified,
    PhotoFailure.missingNutrition,
    PhotoFailure.rateLimited,
  ]) {
    testWidgets('$reason recommends next action while retaining user choice', (
      tester,
    ) async {
      final repo = RecoverySpy(reason);
      final router = await openCapture(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text(reason.message), findsOneWidget);
      await tapAction(tester, '다시 분석');
      expect(repo.requests, 2);
      await tapAction(tester, '다른 사진 선택');
      expect(repo.requests, 3);
      router.go('/blank');
      await tester.pumpAndSettle();
      router.go('/capture');
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 촬영'));
      await tester.pumpAndSettle();
      expect(repo.requests, 4);
      expect(find.text('다시 분석'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'manual entry is available while analysis is pending and late results are ignored',
    (tester) async {
      final repo = RecoverySpy(PhotoFailure.timeout);
      final request = Completer<MealAnalysisResult>();
      repo.pending = request;
      ManualMealPhoto? received;
      await openCapture(tester, repo, onManual: (photo) => received = photo);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tapAction(tester, '사진 첨부해 직접 입력');
      expect(received?.bytes, photoBytes);
      request.complete(
        const MealAnalysisResult(photoPath: 'test/old.png', foods: []),
      );
      await tester.pumpAndSettle();
      expect(repo.discarded, contains('test/old.png'));
      expect(find.byType(MealRecordPage), findsOneWidget);
      expect(find.textContaining('분석 시간이 초과'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'ending a pending analysis permits another photo; old errors do not replace new feedback',
    (tester) async {
      final repo = RecoverySpy(PhotoFailure.blurry);
      final old = Completer<MealAnalysisResult>();
      repo.pending = old;
      await openCapture(tester, repo);
      await tapAction(tester, '분석 대기 종료');
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tapAction(tester, '다른 사진 선택');
      expect(repo.requests, 2);
      expect(find.text(PhotoFailure.blurry.message), findsOneWidget);
      old.completeError(TimeoutException('old request'));
      await tester.pumpAndSettle();
      expect(find.text(PhotoFailure.blurry.message), findsOneWidget);
      expect(find.textContaining('분석 시간이 초과'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
