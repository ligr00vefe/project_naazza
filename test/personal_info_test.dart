import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/auth/presentation/birth_date_field.dart';
import 'package:naazza/features/auth/presentation/personal_info_page.dart';
import 'package:naazza/app/theme/app_theme.dart';

void main() {
  testWidgets('existing user can add, save and remove birth date', (
    tester,
  ) async {
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
    expect(find.byType(BirthDateField), findsOneWidget);
    tester
        .widget<BirthDateField>(find.byType(BirthDateField))
        .onChanged(DateTime(2000, 1, 1));
    await tester.pump();
    expect(find.text('만 ${DateTime.now().year - 2000}세'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('personal-info-save')));
    await tester.pumpAndSettle();
    expect(auth.currentUser!.birthDate, DateTime(2000, 1, 1));
    await tester.tap(find.byTooltip('생년월일 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('personal-info-save')));
    await tester.pumpAndSettle();
    expect(auth.currentUser!.birthDate, isNull);
    expect(tester.takeException(), isNull);
  });
}
