import '../data/login_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signIn(
    String username,
    String pin, {
    bool rememberId = false,
    bool autoLogin = false,
  }) => _authenticate(
    username,
    pin,
    rememberId: rememberId,
    autoLogin: autoLogin,
  );

  Future<void> signUp(
    String username,
    String pin, {
    DateTime? birthDate,
    bool rememberId = false,
    bool autoLogin = false,
  }) => _authenticate(
    username,
    pin,
    signUp: true,
    birthDate: birthDate,
    rememberId: rememberId,
    autoLogin: autoLogin,
  );

  Future<void> _authenticate(
    String username,
    String pin, {
    bool signUp = false,
    DateTime? birthDate,
    required bool rememberId,
    required bool autoLogin,
  }) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final settings = await ref.read(loginPreferencesProvider);
      await settings.setAutoLogin(autoLogin);
      final repository = ref.read(authRepositoryProvider);
      if (signUp) {
        await repository.signUp(
          username: username.trim(),
          pin: pin,
          birthDate: birthDate,
        );
      } else {
        await repository.signIn(username: username.trim(), pin: pin);
      }
      await settings.saveUsername(username, rememberId);
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await (await ref.read(loginPreferencesProvider)).setAutoLogin(false);
      await ref.read(authRepositoryProvider).signOut();
    });
  }
}
