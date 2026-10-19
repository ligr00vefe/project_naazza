import 'package:flutter/material.dart';
import 'package:naazza/features/auth/presentation/login_page.dart';
import 'package:naazza/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:naazza/features/auth/data/login_preferences.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/auth/presentation/auth_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'remembered ID and auto login are independent; no password stored',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = LoginPreferences(prefs);
      await settings.saveUsername('  User_123 ', true);
      expect(settings.username, 'user_123');
      expect(settings.autoLogin, false);
      await settings.setAutoLogin(true);
      await settings.saveUsername('', false);
      expect(settings.username, '');
      expect(settings.autoLogin, true);
      expect(prefs.getKeys(), {'login.remember_id', 'login.auto_login'});
    },
  );
  test(
    'only opted-in sessions survive storage recreation; logout removes tokens',
    () async {
      final settings = LoginPreferences(await SharedPreferences.getInstance());
      OptInSessionStorage storage() => OptInSessionStorage(
        settings,
        SharedPreferencesLocalStorage(persistSessionKey: 'test-session'),
      );
      var first = storage();
      await first.initialize();
      await first.persistSession('not-remembered');
      expect(await first.hasAccessToken(), false);
      await settings.setAutoLogin(true);
      await first.persistSession('session');
      var restarted = storage();
      await restarted.initialize();
      expect(await restarted.accessToken(), 'session');
      await restarted.removePersistedSession();
      expect(await restarted.hasAccessToken(), false);
      await first.persistSession('old-session');
      await settings.setAutoLogin(false);
      restarted = storage();
      await restarted.initialize();
      expect(await restarted.accessToken(), null);
      expect(settings.preferences.containsKey('test-session'), false);
    },
  );
  test(
    'login remembers ID; explicit logout disables auto login and keeps ID',
    () async {
      final settings = LoginPreferences(await SharedPreferences.getInstance());
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
          loginPreferencesProvider.overrideWithValue(Future.value(settings)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      final controller = container.read(authControllerProvider.notifier);
      await controller.signIn(
        'user_123',
        '1234',
        rememberId: true,
        autoLogin: true,
      );
      expect(container.read(authControllerProvider).hasError, false);
      expect(settings.username, 'user_123');
      expect(settings.autoLogin, true);
      await controller.signOut();
      expect(settings.autoLogin, false);
      expect(settings.username, 'user_123');
      expect(container.read(authRepositoryProvider).currentUser, null);
    },
  );
  testWidgets(
    'login page restores saved ID but leaves password empty and allows clearing ID',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'login.remember_id': true,
        'login.username': 'saved_user',
        'login.auto_login': true,
      });
      final settings = LoginPreferences(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(supabaseUrl: '', supabasePublishableKey: ''),
            ),
            authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
            loginPreferencesProvider.overrideWithValue(Future.value(settings)),
          ],
          child: const MaterialApp(home: LoginPage()),
        ),
      );
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[0].controller!.text, 'saved_user');
      expect(fields[1].controller!.text, '');
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((w) => w.value == true),
        true,
      );
      await tester.ensureVisible(find.text('아이디 저장'));
      await tester.tap(find.text('아이디 저장'));
      await tester.pumpAndSettle();
      expect(settings.username, '');
      expect(settings.autoLogin, true);
    },
  );
}
