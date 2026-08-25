import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/app/app.dart';
import 'package:naazza/core/config/app_config.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/tracking_profile/data/demo_tracking_profile_repository.dart';
import 'package:naazza/features/tracking_profile/data/tracking_profile_repository.dart';

void main() {
  testWidgets('로그인 후 맞춤 추적 프로필을 저장하고 홈으로 이동한다', (tester) async {
    final trackingRepository = DemoTrackingProfileRepository();
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
        ],
        child: const NaazzaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('나의 기록이 내일의 변화를 만들어요'), findsOneWidget);
    await tester.tap(find.text('로그인'));
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
      find.text('P1 맞춤 추적 설정 완료'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('P1 맞춤 추적 설정 완료'), findsOneWidget);
    expect(find.text('복통'), findsWidgets);
  });
}
