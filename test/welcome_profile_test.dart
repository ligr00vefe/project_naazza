import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naazza/app/theme/app_theme.dart';
import 'package:naazza/core/config/app_config.dart';
import 'package:naazza/core/widgets/word_wrap_text.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/auth/domain/auth_failure.dart';
import 'package:naazza/features/auth/domain/profile_validation.dart';
import 'package:naazza/features/auth/presentation/login_page.dart';
import 'package:naazza/features/auth/presentation/personal_info_page.dart';
import 'package:naazza/features/home/presentation/welcome_banner.dart';

void main() {
  test(
    'profile name normalizes, persists, clears independently of ID; sex required',
    () async {
      final auth = DemoAuthRepository();
      await expectLater(
        auth.signUp(username: 'tester', pin: '1234'),
        throwsA(isA<AuthFailure>()),
      );
      expect(auth.currentUser, isNull);
      await auth.signUp(username: 'tester', pin: '1234', sex: 'female');
      await auth.updateNutritionProfile(
        displayName: '  민트  ',
        sex: 'female',
        birthDate: DateTime(2000),
      );
      await auth.updateBirthDate(DateTime(1999));
      expect(auth.currentUser!.displayName, '민트');
      await auth.signOut();
      await auth.signIn(username: 'tester', pin: '1234');
      expect(auth.currentUser!.displayName, '민트');
      expect(auth.currentUser!.username, 'tester');
      await expectLater(
        auth.updateNutritionProfile(sex: 'later'),
        throwsA(isA<AuthFailure>()),
      );
      expect(auth.currentUser!.nutritionSex, 'female');
      await auth.updateNutritionProfile(displayName: '', sex: 'male');
      expect(auth.currentUser!.displayName, isNull);
      expect(auth.currentUser!.nutritionSex, 'male');
      expect(
        () => normalizeDisplayName(List.filled(31, '가').join()),
        throwsA(isA<AuthFailure>()),
      );
      expect(() => normalizeDisplayName('민트\n이름'), throwsA(isA<AuthFailure>()));
    },
  );

  testWidgets(
    'profile rejects missing sex, saves name, and does not offer later',
    (tester) async {
      final auth = DemoAuthRepository();
      await tester.runAsync(() => auth.signIn(username: 'tester', pin: '1234'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(auth)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const PersonalInfoPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('나중에 선택'), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('profile-name')), '민트');
      FocusManager.instance.primaryFocus?.unfocus();
      final save = find.byKey(const ValueKey('personal-info-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('성별을 선택해 주세요.'), findsOneWidget);
      expect(auth.currentUser!.displayName, isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('nutrition-sex-female')),
      );
      await tester.tap(find.byKey(const ValueKey('nutrition-sex-female')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(auth.currentUser!.displayName, '민트');
      expect(auth.currentUser!.nutritionSex, 'female');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'signup cannot create account until sex selected; login has no sex field',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = DemoAuthRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            appConfigProvider.overrideWithValue(
              const AppConfig(supabaseUrl: '', supabasePublishableKey: ''),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const LoginPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('성별 · 필수'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('login-mode')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'tester');
      await tester.enterText(find.byType(TextField).at(1), '1234');
      FocusManager.instance.primaryFocus?.unfocus();
      final save = find.byKey(const ValueKey('login-submit'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(auth.currentUser, isNull);
      expect(find.text('성별을 선택해 주세요.'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('nutrition-sex-male')),
      );
      await tester.tap(find.byKey(const ValueKey('nutrition-sex-male')));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(auth.currentUser!.nutritionSex, 'male');
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'small welcome banner handles long names and stable random copy at $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget page(String? name) => MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: WelcomeBanner(displayName: name),
              ),
            ),
          ),
        );
        await tester.pumpWidget(page('민트'));
        await tester.pumpAndSettle();
        expect(find.text('민트님 환영합니다.'), findsOneWidget);
        final message = tester
            .widget<WordWrapText>(
              find.byKey(const ValueKey('home-welcome-message')),
            )
            .text;
        expect(welcomeMessages, contains(message));
        if (scale == 1) {
          expect(
            tester
                .getSize(find.byKey(const ValueKey('home-welcome-banner')))
                .height,
            lessThanOrEqualTo(130),
          );
        }
        await tester.pumpWidget(page(List.filled(30, '가').join()));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<WordWrapText>(
                find.byKey(const ValueKey('home-welcome-message')),
              )
              .text,
          message,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(page(null));
        await tester.pumpAndSettle();
        expect(find.text('오늘도 반가워요!'), findsOneWidget);
        expect(
          tester
              .widget<WordWrapText>(
                find.byKey(const ValueKey('home-welcome-message')),
              )
              .text,
          isNot(message),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
