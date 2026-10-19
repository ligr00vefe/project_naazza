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
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/data/records_repository.dart';
import 'package:naazza/features/records/presentation/meal_record_page.dart';
import 'package:naazza/features/meal_analysis/data/meal_analysis_repository.dart';
import 'package:naazza/features/meal_analysis/data/demo_meal_analysis_repository.dart';
import 'package:naazza/features/meal_analysis/domain/meal_analysis.dart';
import 'package:naazza/features/meal_analysis/presentation/photo_analysis_policy.dart';

class PhotoSpy extends DemoMealAnalysisRepository {
  int uploads = 0, analyses = 0;
  @override
  Future<String> uploadPhoto({
    required String userId,
    required Uint8List imageBytes,
    required String filename,
  }) async {
    uploads++;
    return '$userId/manual.png';
  }

  @override
  Future<MealAnalysisResult> analyze({
    required String userId,
    required Uint8List imageBytes,
    required String filename,
  }) async {
    analyses++;
    return const MealAnalysisResult(photoPath: null, foods: []);
  }
}

void main() {
  testWidgets('20초 안내는 한 번 뜨고 30초에는 응답 없는 요청을 종료한다', (tester) async {
    final request = Completer<int>();
    var warnings = 0;
    Object? error;
    unawaited(
      runPhotoAnalysis(request.future, onSlow: () => warnings++).catchError((
        Object e,
      ) {
        error = e;
        return -1;
      }),
    );
    await tester.pump(const Duration(seconds: 19));
    expect(warnings, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(warnings, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(error, isA<TimeoutException>());
    expect(warnings, 1);
    request.complete(1);
    await tester.pump();
  });
  test('서버 무응답 두 번을 인식 불가 상품으로 단정하지 않는다', () {
    expect(
      photoFailureMessage(timedOut: true, failures: 2),
      contains('분석 시간이 초과'),
    );
    expect(
      photoFailureMessage(timedOut: true, failures: 2),
      isNot(contains('상품')),
    );
    expect(
      photoFailureMessage(timedOut: false, failures: 2),
      contains('직접 입력'),
    );
    expect(
      photoFailureMessage(timedOut: false, failures: 1),
      contains('다른 사진'),
    );
  });
  testWidgets('직접 입력 사진 첨부는 AI를 호출하지 않고 기록에 저장된다', (tester) async {
    final repo = DemoRecordsRepository(),
        auth = DemoAuthRepository(),
        photo = PhotoSpy();
    await tester.runAsync(() => auth.signIn(username: 'tester', pin: '1234'));
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aO1sAAAAASUVORK5CYII=',
    );
    final router = GoRouter(
      initialLocation: '/manual',
      routes: [
        GoRoute(
          path: '/manual',
          builder: (_, _) => MealRecordPage(
            pickImage: (_) async =>
                XFile.fromData(bytes, name: 'meal.png', mimeType: 'image/png'),
          ),
        ),
        GoRoute(
          path: '/timeline',
          builder: (_, _) => const Scaffold(body: Text('저장 완료')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          recordsRepositoryProvider.overrideWithValue(repo),
          mealAnalysisRepositoryProvider.overrideWithValue(photo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('사진 선택'));
    await tester.pumpAndSettle();
    expect(find.text('사진 삭제'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '직접 기록한 음식');
    await tester.enterText(find.byType(TextField).at(2), '123.5');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 저장하기'));
    await tester.pumpAndSettle();
    final record = (await repo.list('demo-user')).single;
    expect(record.data['photo_path'], 'demo-user/manual.png');
    expect(record.data['energy_kcal'], 123.5);
    expect(photo.uploads, 1);
    expect(photo.analyses, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'missing calories remain unknown when saving an identified product',
    (tester) async {
      final repo = DemoRecordsRepository(), auth = DemoAuthRepository();
      await tester.runAsync(() => auth.signIn(username: 'tester', pin: '1234'));
      final router = GoRouter(
        initialLocation: '/manual',
        routes: [
          GoRoute(
            path: '/manual',
            builder: (_, _) => MealRecordPage(
              initialPhoto: ManualMealPhoto(
                bytes: base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aO1sAAAAASUVORK5CYII=',
                ),
                filename: 'test.png',
                productName: '퀴노아 크래커',
              ),
            ),
          ),
          GoRoute(path: '/timeline', builder: (_, _) => const Scaffold()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            recordsRepositoryProvider.overrideWithValue(repo),
            mealAnalysisRepositoryProvider.overrideWithValue(PhotoSpy()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('기록 저장하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('기록 저장하기'));
      await tester.pumpAndSettle();
      final record = (await repo.list('demo-user')).single;
      expect(record.title, '퀴노아 크래커');
      expect(record.data['energy_kcal'], isNull);
      expect(record.data['nutrition_known'], false);
      expect(record.summary, contains('열량 미기록'));
      expect(tester.takeException(), isNull);
    },
  );
}
