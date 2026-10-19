import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final loginPreferencesProvider = Provider<Future<LoginPreferences>>(
  (ref) async => LoginPreferences(await SharedPreferences.getInstance()),
);

class LoginPreferences {
  LoginPreferences(this.preferences);
  final SharedPreferences preferences;
  bool get rememberId => preferences.getBool('login.remember_id') ?? false;
  bool get autoLogin => preferences.getBool('login.auto_login') ?? false;
  String get username =>
      rememberId ? preferences.getString('login.username') ?? '' : '';
  Future<void> setAutoLogin(bool enabled) async {
    if (!await preferences.setBool('login.auto_login', enabled)) {
      throw StateError('로그인 설정을 저장하지 못했어.');
    }
  }

  Future<void> saveUsername(String username, bool remember) async {
    await preferences.setBool('login.remember_id', remember);
    if (remember) {
      await preferences.setString(
        'login.username',
        username.trim().toLowerCase(),
      );
    } else {
      await preferences.remove('login.username');
    }
  }
}

// Keep the current in-memory session, but persist it only with explicit opt-in.
class OptInSessionStorage extends LocalStorage {
  OptInSessionStorage(this.settings, this.delegate);
  final LoginPreferences settings;
  final LocalStorage delegate;
  @override
  Future<void> initialize() async {
    await delegate.initialize();
    if (!settings.autoLogin) await delegate.removePersistedSession();
  }

  @override
  Future<bool> hasAccessToken() async =>
      settings.autoLogin && await delegate.hasAccessToken();
  @override
  Future<String?> accessToken() async =>
      settings.autoLogin ? await delegate.accessToken() : null;
  @override
  Future<void> persistSession(String value) async {
    if (settings.autoLogin) {
      await delegate.persistSession(value);
    } else {
      await delegate.removePersistedSession();
    }
  }

  @override
  Future<void> removePersistedSession() => delegate.removePersistedSession();
}
