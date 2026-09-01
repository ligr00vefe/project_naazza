import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/app/app.dart';
import 'package:naazza/core/config/app_config.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/auth/domain/auth_user.dart';
import 'package:naazza/features/auth/presentation/login_page.dart';
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/data/records_repository.dart';
import 'package:naazza/features/records/domain/health_record.dart';
import 'package:naazza/features/meal_analysis/data/demo_meal_analysis_repository.dart';
import 'package:naazza/features/meal_analysis/data/meal_analysis_repository.dart';
import 'package:naazza/features/insights/domain/insight_summary.dart';
import 'package:naazza/features/tracking_profile/data/demo_tracking_profile_repository.dart';
import 'package:naazza/features/tracking_profile/data/tracking_profile_repository.dart';
import 'package:naazza/features/visits/domain/visit_preparation.dart';

void main() {
  testWidgets('회원가입 후 이메일 인증 대기와 재전송 흐름을 안내한다', (tester) async {
    final authRepository = _ConfirmationAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              supabaseUrl: 'https://example.supabase.co',
              supabasePublishableKey: 'publishable-key',
            ),
          ),
          authRepositoryProvider.overrideWithValue(authRepository),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('처음인가요? 이메일로 회원가입'));
    await tester.pump();
    expect(find.text('가입하고 인증 메일 받기'), findsOneWidget);
    expect(find.textContaining('인증 메일을 보내드려요'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password1');
    await tester.enterText(find.byType(TextField).at(2), 'password1');
    await tester.tap(find.text('가입하고 인증 메일 받기'));
    await tester.pump();

    expect(find.text('인증 메일을 보냈어요'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(authRepository.signUpCount, 1);

    await tester.tap(find.text('인증 메일 다시 보내기'));
    await tester.pump();
    expect(authRepository.resendCount, 1);
  });

  testWidgets('로그인 후 맞춤 추적 프로필을 저장하고 홈으로 이동한다', (tester) async {
    final trackingRepository = DemoTrackingProfileRepository();
    final recordsRepository = DemoRecordsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(supabaseUrl: '', supabasePublishableKey: ''),
          ),
          authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
          trackingProfileRepositoryProvider.overrideWithValue(
            trackingRepository,
          ),
          recordsRepositoryProvider.overrideWithValue(recordsRepository),
          mealAnalysisRepositoryProvider.overrideWithValue(
            DemoMealAnalysisRepository(),
          ),
        ],
        child: const NaazzaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('나의 기록이 내일의 변화를 만들어요'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    expect(find.text('1. 관리 목표를 선택해 주세요'), findsOneWidget);
    await tester.tap(find.text('크론병 / 궤양성 대장염'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('배변'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('배변'), findsOneWidget);
    final saveButton = find.widgetWithText(FilledButton, '설정 완료하고 시작하기');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    await tester.tap(saveButton);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(await trackingRepository.load('demo-user'), isNotNull);
    expect(find.text('빠른 기록'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('P4 기록 인사이트'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('P4 기록 인사이트'), findsOneWidget);
    expect(find.text('복통'), findsWidgets);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('식사 기록').first);
    await tester.pumpAndSettle();
    expect(find.text('음식 사진 기록'), findsOneWidget);
    await tester.tap(find.text('사진 없이 직접 입력하기'));
    await tester.pumpAndSettle();
    expect(find.text('식사 직접 입력'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '제육볶음');
    await tester.enterText(find.byType(TextField).at(2), '520');
    await tester.tap(find.text('기록 저장하기'));
    await tester.pumpAndSettle();
    expect(await recordsRepository.list('demo-user'), hasLength(1));
  });

  test('데모 기록 저장소가 생성·수정·삭제를 지원한다', () async {
    final repository = DemoRecordsRepository();
    final record = HealthRecord(
      id: 'meal-1',
      userId: 'user-1',
      type: HealthRecordType.meal,
      recordedAt: DateTime(2026, 8, 26, 12, 30),
      title: '제육볶음',
      summary: '1인분 · 520 kcal',
      data: const {'meal_type': 'lunch'},
    );
    await repository.create(record);
    expect(await repository.list('user-1'), hasLength(1));
    await repository.update(record.copyWith(title: '제육볶음과 밥'));
    expect((await repository.list('user-1')).single.title, '제육볶음과 밥');
    await repository.delete('user-1', record);
    expect(await repository.list('user-1'), isEmpty);
  });

  test('데모 음식 분석 결과가 영양값을 섭취량에 맞게 계산한다', () async {
    final repository = DemoMealAnalysisRepository();
    final result = await repository.analyze(
      userId: 'user-1',
      imageBytes: Uint8List.fromList([0]),
      filename: 'meal.jpg',
    );
    expect(result.foods, hasLength(3));
    final rice = result.foods.firstWhere((food) => food.name == '밥');
    expect(rice.nutrition.forAmount(rice.amountG).energyKcal.round(), 300);
    expect(result.foods.last.confidence, lessThan(0.85));
  });

  test('데모 바코드 조회가 제품과 섭취량 기준 영양정보를 반환한다', () async {
    final repository = DemoMealAnalysisRepository();
    final product = await repository.lookupBarcode('8801234567890');
    expect(product, isNotNull);
    expect(product!.name, contains('크래커'));
    expect(
      product.nutrition.forAmount(product.amountG).energyKcal.round(),
      129,
    );
  });

  test('인사이트가 기간 내 기록만 집계하고 핵심 지표를 계산한다', () {
    final now = DateTime(2026, 8, 26, 20);
    final records = [
      HealthRecord(
        id: 'm1',
        userId: 'u1',
        type: HealthRecordType.meal,
        recordedAt: now,
        title: '점심',
        summary: '',
        data: const {'meal_type': 'lunch', 'energy_kcal': 500},
      ),
      HealthRecord(
        id: 'm2',
        userId: 'u1',
        type: HealthRecordType.meal,
        recordedAt: now.subtract(const Duration(days: 1)),
        title: '점심',
        summary: '',
        data: const {'meal_type': 'lunch', 'energy_kcal': 700},
      ),
      HealthRecord(
        id: 'c1',
        userId: 'u1',
        type: HealthRecordType.condition,
        recordedAt: now,
        title: '증상',
        summary: '',
        data: const {
          'response_status': 'symptom',
          'symptoms': ['복통'],
        },
      ),
      HealthRecord(
        id: 'b1',
        userId: 'u1',
        type: HealthRecordType.bowel,
        recordedAt: now.subtract(const Duration(days: 2)),
        title: '배변',
        summary: '',
        data: const {'bristol_type': 4},
      ),
      HealthRecord(
        id: 'old',
        userId: 'u1',
        type: HealthRecordType.meal,
        recordedAt: now.subtract(const Duration(days: 40)),
        title: '제외',
        summary: '',
        data: const {'energy_kcal': 100},
      ),
    ];
    final summary = InsightSummary.fromRecords(records, days: 30, now: now);
    expect(summary.totalRecords, 4);
    expect(summary.activeDays, 3);
    expect(summary.averageEnergyKcal, 600);
    expect(summary.averageBristol, 4);
    expect(summary.topSymptoms['복통'], 1);
    expect(summary.dailyActivity.reduce((a, b) => a + b), 4);
  });

  test('진료 준비 요약이 이전 내원 이후 기록과 질문을 집계한다', () {
    final previous = HealthRecord(
      id: 'v1',
      userId: 'u1',
      type: HealthRecordType.visit,
      recordedAt: DateTime(2026, 7, 1),
      title: '이전 진료',
      summary: '',
      data: const {},
    );
    final upcoming = HealthRecord(
      id: 'v2',
      userId: 'u1',
      type: HealthRecordType.visit,
      recordedAt: DateTime(2026, 8, 26),
      title: '정기 진료',
      summary: '',
      data: const {
        'questions': ['약 용량을 조절할까요?'],
      },
    );
    final records = <HealthRecord>[
      previous,
      upcoming,
      HealthRecord(
        id: 'm1',
        userId: 'u1',
        type: HealthRecordType.meal,
        recordedAt: DateTime(2026, 8, 1),
        title: '식사',
        summary: '',
        data: const {},
      ),
      HealthRecord(
        id: 'c1',
        userId: 'u1',
        type: HealthRecordType.condition,
        recordedAt: DateTime(2026, 8, 2),
        title: '증상',
        summary: '',
        data: const {
          'response_status': 'symptom',
          'symptoms': ['복통'],
        },
      ),
      HealthRecord(
        id: 'b1',
        userId: 'u1',
        type: HealthRecordType.bowel,
        recordedAt: DateTime(2026, 8, 3),
        title: '배변',
        summary: '',
        data: const {},
      ),
    ];
    final summary = VisitPreparation.build(records, upcoming);
    expect(summary.meals, 1);
    expect(summary.symptomLogs, 1);
    expect(summary.bowelLogs, 1);
    expect(summary.topSymptoms['복통'], 1);
    expect(summary.questions.single, contains('약 용량'));
  });
}

class _ConfirmationAuthRepository implements AuthRepository {
  int signUpCount = 0;
  int resendCount = 0;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(null);

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    signUpCount += 1;
    return const SignUpResult(requiresEmailConfirmation: true);
  }

  @override
  Future<void> resendSignUpConfirmation({required String email}) async {
    resendCount += 1;
  }

  @override
  Future<void> signOut() async {}
}
